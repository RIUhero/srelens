export const TASK_STATES = ["UNVERIFIED", "BLOCKED", "PASS"] as const;
export type TaskState = (typeof TASK_STATES)[number];

export const PROVIDER_FAMILIES = ["native-cli", "local-openai-compatible"] as const;
export type ProviderFamily = (typeof PROVIDER_FAMILIES)[number];

export const SAFE_EVENTS = ["projection_observed", "acceptance_pending", "acceptance_passed"] as const;
export type SafeEvent = (typeof SAFE_EVENTS)[number];

export interface CoreTaskProjection {
  readonly taskPublicId: string;
  readonly state: TaskState;
  readonly providerFamily: ProviderFamily;
  readonly workspacePublicRef: string;
  readonly parentPublicRef: string | null;
  readonly updatedAt: string;
  readonly safeEvent: SafeEvent;
}

export interface CoreProjection {
  readonly tasks: readonly CoreTaskProjection[];
}

export interface CoreProjectionReader {
  readonly source: "static-redacted-fixture" | "core-read-only-capability";
  readonly productionUsable: boolean;
  read(): Promise<CoreProjection>;
}

const PROJECTION_KEYS = ["tasks"] as const;
const TASK_KEYS = [
  "taskPublicId",
  "state",
  "providerFamily",
  "workspacePublicRef",
  "parentPublicRef",
  "updatedAt",
  "safeEvent",
] as const;
const PUBLIC_REF = /^[a-z][a-z0-9_-]{2,63}$/;

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

function hasExactKeys(value: Record<string, unknown>, expected: readonly string[]): boolean {
  const actual = Object.keys(value).sort();
  const wanted = [...expected].sort();
  return actual.length === wanted.length && actual.every((key, index) => key === wanted[index]);
}

function isOneOf<T extends string>(value: unknown, allowed: readonly T[]): value is T {
  return typeof value === "string" && allowed.includes(value as T);
}

function isPublicRef(value: unknown): value is string {
  return typeof value === "string" && PUBLIC_REF.test(value);
}

function isCanonicalTimestamp(value: unknown): value is string {
  if (typeof value !== "string") return false;
  const parsed = new Date(value);
  return !Number.isNaN(parsed.valueOf()) && parsed.toISOString() === value;
}

function parseTask(value: unknown): CoreTaskProjection {
  if (!isRecord(value) || !hasExactKeys(value, TASK_KEYS)) {
    throw new Error("Core projection rejected: task fields are not allowlisted");
  }
  if (!isPublicRef(value.taskPublicId) || !isPublicRef(value.workspacePublicRef)) {
    throw new Error("Core projection rejected: invalid public reference");
  }
  if (value.parentPublicRef !== null && !isPublicRef(value.parentPublicRef)) {
    throw new Error("Core projection rejected: invalid parent public reference");
  }
  if (!isOneOf(value.state, TASK_STATES)) {
    throw new Error("Core projection rejected: invalid state");
  }
  if (!isOneOf(value.providerFamily, PROVIDER_FAMILIES)) {
    throw new Error("Core projection rejected: invalid provider family");
  }
  if (!isOneOf(value.safeEvent, SAFE_EVENTS)) {
    throw new Error("Core projection rejected: unsafe event");
  }
  if (!isCanonicalTimestamp(value.updatedAt)) {
    throw new Error("Core projection rejected: invalid timestamp");
  }
  return Object.freeze({
    taskPublicId: value.taskPublicId,
    state: value.state,
    providerFamily: value.providerFamily,
    workspacePublicRef: value.workspacePublicRef,
    parentPublicRef: value.parentPublicRef,
    updatedAt: value.updatedAt,
    safeEvent: value.safeEvent,
  });
}

/** Strict allowlist boundary. Unknown or sensitive fields fail closed. */
export function parseCoreProjection(value: unknown): CoreProjection {
  if (!isRecord(value) || !hasExactKeys(value, PROJECTION_KEYS) || !Array.isArray(value.tasks)) {
    throw new Error("Core projection rejected: invalid envelope");
  }
  return Object.freeze({ tasks: Object.freeze(value.tasks.map(parseTask)) });
}

export class StaticCoreProjectionReader implements CoreProjectionReader {
  readonly source = "static-redacted-fixture" as const;
  readonly productionUsable = false;

  constructor(private readonly fixture: unknown) {}

  async read(): Promise<CoreProjection> {
    // Validation runs on every read so a caller cannot mutate an accepted
    // fixture and bypass the allowlist later.
    return parseCoreProjection(this.fixture);
  }
}
