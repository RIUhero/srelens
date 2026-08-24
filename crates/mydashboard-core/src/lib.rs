//! Minimal provider-free MyDashboard Core process.
//!
//! Phase B deliberately exposes one operation: reading an empty, strictly
//! redacted projection.  It owns no canonical task state, opens no network or
//! credential source, and accepts no mutation.  The workstation launches this
//! server as the exact current executable in `--mydashboard-core-stdio` mode.

use std::io::{self, BufRead, Write};

use serde::{Deserialize, Serialize};

pub const PROTOCOL_VERSION: u8 = 1;

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct CoreProjection {
    pub tasks: Vec<CoreTaskProjection>,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
#[serde(rename_all = "camelCase")]
pub struct CoreTaskProjection {
    pub task_public_id: String,
    pub state: TaskState,
    pub provider_family: ProviderFamily,
    pub workspace_public_ref: String,
    pub parent_public_ref: Option<String>,
    pub updated_at: String,
    pub safe_event: SafeEvent,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "SCREAMING_SNAKE_CASE")]
pub enum TaskState {
    Unverified,
    Blocked,
    Pass,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
pub enum ProviderFamily {
    #[serde(rename = "native-cli")]
    NativeCli,
    #[serde(rename = "local-openai-compatible")]
    LocalOpenAiCompatible,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum SafeEvent {
    ProjectionObserved,
    AcceptancePending,
    AcceptancePassed,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum Operation {
    ReadProjection,
    Shutdown,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct Request {
    pub version: u8,
    pub operation: Operation,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(deny_unknown_fields, tag = "status", rename_all = "snake_case")]
pub enum Response {
    Ok {
        version: u8,
        projection: Option<CoreProjection>,
    },
    Error {
        version: u8,
        code: ErrorCode,
    },
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum ErrorCode {
    InvalidRequest,
    UnsupportedVersion,
}

pub fn read_projection_request() -> Request {
    Request {
        version: PROTOCOL_VERSION,
        operation: Operation::ReadProjection,
    }
}

pub fn shutdown_request() -> Request {
    Request {
        version: PROTOCOL_VERSION,
        operation: Operation::Shutdown,
    }
}

/// The Phase B Core owns no canonical state yet.  A live empty projection is
/// intentionally different from the Phase A browser fixture: it proves the
/// process and transport while inventing no task, provider, or workspace data.
pub fn current_projection() -> CoreProjection {
    CoreProjection { tasks: Vec::new() }
}

fn write_response<W: Write>(writer: &mut W, response: &Response) -> io::Result<()> {
    serde_json::to_writer(&mut *writer, response)?;
    writer.write_all(b"\n")?;
    writer.flush()
}

/// Serve newline-delimited, typed requests until EOF or an explicit shutdown.
/// Malformed input receives only a stable error code; raw input is never
/// reflected into a response or diagnostic.
pub fn serve<R: BufRead, W: Write>(mut reader: R, mut writer: W) -> io::Result<()> {
    let mut line = String::new();
    loop {
        line.clear();
        if reader.read_line(&mut line)? == 0 {
            return Ok(());
        }

        let request = match serde_json::from_str::<Request>(line.trim_end()) {
            Ok(request) => request,
            Err(_) => {
                write_response(
                    &mut writer,
                    &Response::Error {
                        version: PROTOCOL_VERSION,
                        code: ErrorCode::InvalidRequest,
                    },
                )?;
                continue;
            }
        };

        if request.version != PROTOCOL_VERSION {
            write_response(
                &mut writer,
                &Response::Error {
                    version: PROTOCOL_VERSION,
                    code: ErrorCode::UnsupportedVersion,
                },
            )?;
            continue;
        }

        match request.operation {
            Operation::ReadProjection => write_response(
                &mut writer,
                &Response::Ok {
                    version: PROTOCOL_VERSION,
                    projection: Some(current_projection()),
                },
            )?,
            Operation::Shutdown => {
                write_response(
                    &mut writer,
                    &Response::Ok {
                        version: PROTOCOL_VERSION,
                        projection: None,
                    },
                )?;
                return Ok(());
            }
        }
    }
}

pub fn run_stdio() -> io::Result<()> {
    let stdin = io::stdin();
    let stdout = io::stdout();
    serve(stdin.lock(), stdout.lock())
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::io::Cursor;

    fn responses(input: &str) -> Vec<Response> {
        let mut output = Vec::new();
        serve(Cursor::new(input.as_bytes()), &mut output).unwrap();
        String::from_utf8(output)
            .unwrap()
            .lines()
            .map(|line| serde_json::from_str(line).unwrap())
            .collect()
    }

    #[test]
    fn live_projection_is_empty_instead_of_inventing_canonical_state() {
        let input = format!(
            "{}\n{}\n",
            serde_json::to_string(&read_projection_request()).unwrap(),
            serde_json::to_string(&shutdown_request()).unwrap()
        );
        assert_eq!(
            responses(&input),
            vec![
                Response::Ok {
                    version: PROTOCOL_VERSION,
                    projection: Some(CoreProjection { tasks: vec![] }),
                },
                Response::Ok {
                    version: PROTOCOL_VERSION,
                    projection: None,
                },
            ]
        );
    }

    #[test]
    fn malformed_and_unknown_fields_fail_closed_without_echoing_input() {
        let output = responses(
            "{\"version\":1,\"operation\":\"read_projection\",\"rawPrompt\":\"secret\"}\nnot-json\n",
        );
        assert_eq!(
            output,
            vec![
                Response::Error {
                    version: PROTOCOL_VERSION,
                    code: ErrorCode::InvalidRequest,
                },
                Response::Error {
                    version: PROTOCOL_VERSION,
                    code: ErrorCode::InvalidRequest,
                },
            ]
        );
        let rendered = serde_json::to_string(&output).unwrap();
        assert!(!rendered.contains("secret"));
        assert!(!rendered.contains("rawPrompt"));
    }

    #[test]
    fn unsupported_version_returns_a_stable_safe_code() {
        let output = responses("{\"version\":2,\"operation\":\"read_projection\"}\n");
        assert_eq!(
            output,
            vec![Response::Error {
                version: PROTOCOL_VERSION,
                code: ErrorCode::UnsupportedVersion,
            }]
        );
    }

    #[test]
    fn eof_is_a_clean_shutdown() {
        assert!(responses("").is_empty());
    }

    #[test]
    fn projection_schema_rejects_sensitive_or_unknown_fields() {
        let value = serde_json::json!({
            "tasks": [{
                "taskPublicId": "task_public_001",
                "state": "PASS",
                "providerFamily": "native-cli",
                "workspacePublicRef": "workspace_alpha",
                "parentPublicRef": null,
                "updatedAt": "2026-08-25T00:00:00.000Z",
                "safeEvent": "projection_observed",
                "rawPrompt": "secret"
            }]
        });
        assert!(serde_json::from_value::<CoreProjection>(value).is_err());
    }
}
