//! Thin desktop adapter for the provider-free MyDashboard Core process.
//!
//! The child is the exact current `srelens` executable in a dedicated stdio
//! mode.  It receives an empty environment, exposes one read-only operation,
//! and is held behind the existing capability registry.  No path, child PID,
//! stderr, or raw protocol error crosses the capability boundary.

use std::path::PathBuf;
use std::process::Stdio;
use std::sync::Arc;
use std::time::Duration;

use srelens_capability::{Capability, CapabilityError, Registry};
use srelens_mydashboard_core::{
    read_projection_request, shutdown_request, CoreProjection, Response, PROTOCOL_VERSION,
};
use tokio::io::{AsyncBufReadExt, AsyncWriteExt, BufReader};
use tokio::process::{Child, ChildStdin, ChildStdout, Command};
use tokio::sync::Mutex;
use tokio::time::timeout;

pub const CORE_PROJECTION_CAPABILITY_ID: &str = "mydashboard.readProjection";
const CORE_MODE_ARG: &str = "--mydashboard-core-stdio";
const OPERATION_TIMEOUT: Duration = Duration::from_secs(5);

struct RunningCore {
    child: Child,
    stdin: ChildStdin,
    stdout: BufReader<ChildStdout>,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
enum CoreBridgeError {
    Unavailable,
    Timeout,
    Protocol,
}

/// Lazily owns one Core child.  The module-disabled path never calls the
/// capability, so it creates no process or state.
pub struct CoreProcessManager {
    executable: Option<PathBuf>,
    running: Mutex<Option<RunningCore>>,
}

impl CoreProcessManager {
    pub fn from_current_exe() -> Self {
        Self::new(std::env::current_exe().ok())
    }

    fn new(executable: Option<PathBuf>) -> Self {
        Self {
            executable,
            running: Mutex::new(None),
        }
    }

    fn spawn(&self) -> Result<RunningCore, CoreBridgeError> {
        let executable = self
            .executable
            .as_ref()
            .ok_or(CoreBridgeError::Unavailable)?;
        let mut command = Command::new(executable);
        command
            .arg(CORE_MODE_ARG)
            .env_clear()
            .stdin(Stdio::piped())
            .stdout(Stdio::piped())
            .stderr(Stdio::null())
            .kill_on_drop(true);
        let mut child = command.spawn().map_err(|_| CoreBridgeError::Unavailable)?;
        let stdin = child.stdin.take().ok_or(CoreBridgeError::Unavailable)?;
        let stdout = child.stdout.take().ok_or(CoreBridgeError::Unavailable)?;
        Ok(RunningCore {
            child,
            stdin,
            stdout: BufReader::new(stdout),
        })
    }

    async fn request_projection(
        running: &mut RunningCore,
    ) -> Result<CoreProjection, CoreBridgeError> {
        if running
            .child
            .try_wait()
            .map_err(|_| CoreBridgeError::Unavailable)?
            .is_some()
        {
            return Err(CoreBridgeError::Unavailable);
        }

        let mut request = serde_json::to_vec(&read_projection_request())
            .map_err(|_| CoreBridgeError::Protocol)?;
        request.push(b'\n');
        timeout(OPERATION_TIMEOUT, running.stdin.write_all(&request))
            .await
            .map_err(|_| CoreBridgeError::Timeout)?
            .map_err(|_| CoreBridgeError::Unavailable)?;
        timeout(OPERATION_TIMEOUT, running.stdin.flush())
            .await
            .map_err(|_| CoreBridgeError::Timeout)?
            .map_err(|_| CoreBridgeError::Unavailable)?;

        let mut line = String::new();
        let bytes = timeout(OPERATION_TIMEOUT, running.stdout.read_line(&mut line))
            .await
            .map_err(|_| CoreBridgeError::Timeout)?
            .map_err(|_| CoreBridgeError::Unavailable)?;
        if bytes == 0 {
            return Err(CoreBridgeError::Unavailable);
        }
        match serde_json::from_str::<Response>(line.trim_end())
            .map_err(|_| CoreBridgeError::Protocol)?
        {
            Response::Ok {
                version,
                projection: Some(projection),
            } if version == PROTOCOL_VERSION => Ok(projection),
            _ => Err(CoreBridgeError::Protocol),
        }
    }

    async fn discard(running: &mut Option<RunningCore>) {
        if let Some(mut child) = running.take() {
            let _ = child.child.start_kill();
            let _ = timeout(OPERATION_TIMEOUT, child.child.wait()).await;
        }
    }

    pub async fn read_projection(&self) -> Result<CoreProjection, ()> {
        let mut running = timeout(OPERATION_TIMEOUT, self.running.lock())
            .await
            .map_err(|_| ())?;
        if running.is_none() {
            *running = Some(self.spawn().map_err(|_| ())?);
        }
        let result = Self::request_projection(running.as_mut().expect("core inserted")).await;
        if result.is_err() {
            Self::discard(&mut running).await;
        }
        result.map_err(|_| ())
    }

    #[allow(dead_code)]
    pub async fn shutdown(&self) {
        let Ok(mut running) = timeout(OPERATION_TIMEOUT, self.running.lock()).await else {
            return;
        };
        let Some(mut child) = running.take() else {
            return;
        };
        let request = serde_json::to_vec(&shutdown_request());
        if let Ok(mut request) = request {
            request.push(b'\n');
            let _ = timeout(OPERATION_TIMEOUT, child.stdin.write_all(&request)).await;
            let _ = timeout(OPERATION_TIMEOUT, child.stdin.flush()).await;
            let mut line = String::new();
            if let Ok(Ok(bytes)) =
                timeout(OPERATION_TIMEOUT, child.stdout.read_line(&mut line)).await
            {
                if bytes > 0
                    && matches!(
                        serde_json::from_str::<Response>(line.trim_end()),
                        Ok(Response::Ok {
                            version: PROTOCOL_VERSION,
                            projection: None
                        })
                    )
                    && matches!(
                        timeout(OPERATION_TIMEOUT, child.child.wait()).await,
                        Ok(Ok(_))
                    )
                {
                    return;
                }
            }
        }
        let _ = child.child.start_kill();
        let _ = timeout(OPERATION_TIMEOUT, child.child.wait()).await;
    }
}

/// `option_env!` is tracked by Cargo, so the same exact source can produce a
/// default-OFF package with no Core capability and an explicitly enabled
/// package with the read-only capability.
pub fn feature_compiled() -> bool {
    option_env!("VITE_SRELENS_MYDASHBOARD") == Some("1")
}

pub fn register(registry: &mut Registry, manager: Arc<CoreProcessManager>) {
    registry.register(Capability::read_only(
        CORE_PROJECTION_CAPABILITY_ID,
        "Read the strict redacted MyDashboard Core projection",
        move |input| {
            let manager = manager.clone();
            async move {
                if !input.is_null() {
                    return Err(CapabilityError::InvalidInput(
                        "mydashboard projection input must be null".into(),
                    ));
                }
                let projection = manager
                    .read_projection()
                    .await
                    .map_err(|_| CapabilityError::Handler("mydashboard_core_unavailable".into()))?;
                serde_json::to_value(projection)
                    .map_err(|_| CapabilityError::Handler("mydashboard_core_protocol_error".into()))
            }
        },
    ));
}

#[cfg(test)]
mod tests {
    use super::*;
    use serde_json::json;

    #[test]
    fn registration_is_one_read_only_non_sensitive_capability() {
        let manager = Arc::new(CoreProcessManager::new(None));
        let mut registry = Registry::new();
        register(&mut registry, manager);
        assert_eq!(registry.ids(), vec![CORE_PROJECTION_CAPABILITY_ID]);
        let capability = registry.get(CORE_PROJECTION_CAPABILITY_ID).unwrap();
        assert!(capability.annotations.read_only);
        assert!(!capability.annotations.destructive);
        assert!(!capability.annotations.requires_confirm);
        assert!(!capability.annotations.sensitive);
    }

    #[tokio::test]
    async fn non_null_input_is_rejected_before_any_process_is_spawned() {
        let manager = Arc::new(CoreProcessManager::new(None));
        let mut registry = Registry::new();
        register(&mut registry, manager);
        let error = registry
            .invoke(CORE_PROJECTION_CAPABILITY_ID, json!({"mutation": true}))
            .await
            .unwrap_err();
        assert!(matches!(error, CapabilityError::InvalidInput(_)));
    }

    #[tokio::test]
    async fn unavailable_process_returns_only_a_stable_safe_error() {
        let manager = Arc::new(CoreProcessManager::new(None));
        let mut registry = Registry::new();
        register(&mut registry, manager);
        let error = registry
            .invoke(CORE_PROJECTION_CAPABILITY_ID, serde_json::Value::Null)
            .await
            .unwrap_err();
        assert_eq!(
            error.to_string(),
            "handler error: mydashboard_core_unavailable"
        );
    }

    #[tokio::test]
    #[ignore = "requires the exact built desktop executable"]
    async fn empirical_exact_binary_bridge_reads_and_shuts_down_cleanly() {
        let executable = std::env::var_os("SRELENS_PHASE_B_BINARY")
            .map(PathBuf::from)
            .expect("SRELENS_PHASE_B_BINARY must bind the exact built executable");
        let manager = CoreProcessManager::new(Some(executable));
        assert_eq!(manager.read_projection().await.unwrap().tasks, vec![]);
        manager.shutdown().await;
        assert!(manager.running.lock().await.is_none());
    }
}
