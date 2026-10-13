export const ErrorCode = {
  VALIDATION_ERROR: 'VALIDATION_ERROR',
  USER_NOT_IDENTIFIED: 'USER_NOT_IDENTIFIED',
  LESSON_LOCKED: 'LESSON_LOCKED',
  NOT_FOUND: 'NOT_FOUND',
  ATTEMPT_NOT_ACTIVE: 'ATTEMPT_NOT_ACTIVE',
  CONTENT_CHANGED: 'CONTENT_CHANGED',
  ANSWER_INVALID: 'ANSWER_INVALID',
  INCOMPLETE_ATTEMPT: 'INCOMPLETE_ATTEMPT',
  FEEDBACK_INVALID: 'FEEDBACK_INVALID',
  INTERNAL_ERROR: 'INTERNAL_ERROR',
} as const;

export type ErrorCode = (typeof ErrorCode)[keyof typeof ErrorCode];

const STATUS: Record<ErrorCode, number> = {
  VALIDATION_ERROR: 400,
  USER_NOT_IDENTIFIED: 401,
  LESSON_LOCKED: 403,
  NOT_FOUND: 404,
  ATTEMPT_NOT_ACTIVE: 409,
  CONTENT_CHANGED: 409,
  ANSWER_INVALID: 422,
  INCOMPLETE_ATTEMPT: 422,
  FEEDBACK_INVALID: 422,
  INTERNAL_ERROR: 500,
};

/** An expected, client-facing error. Its message and details are sent to the client verbatim. */
export class AppError extends Error {
  readonly status: number;

  constructor(
    readonly code: ErrorCode,
    message: string,
    readonly details?: unknown,
  ) {
    super(message);
    this.name = 'AppError';
    this.status = STATUS[code];
  }

  static validation(message: string, details?: unknown) {
    return new AppError(ErrorCode.VALIDATION_ERROR, message, details);
  }
  static userNotIdentified(message = 'A valid X-User-Id header is required') {
    return new AppError(ErrorCode.USER_NOT_IDENTIFIED, message);
  }
  static lessonLocked(message = 'This lesson is locked') {
    return new AppError(ErrorCode.LESSON_LOCKED, message);
  }
  static notFound(message = 'Resource not found') {
    return new AppError(ErrorCode.NOT_FOUND, message);
  }
  static attemptNotActive(message = 'This attempt is no longer active') {
    return new AppError(ErrorCode.ATTEMPT_NOT_ACTIVE, message);
  }
  static contentChanged(message = 'The lesson content changed during this attempt') {
    return new AppError(ErrorCode.CONTENT_CHANGED, message);
  }
  static answerInvalid(message: string, details?: unknown) {
    return new AppError(ErrorCode.ANSWER_INVALID, message, details);
  }
  static incompleteAttempt(message: string, details?: unknown) {
    return new AppError(ErrorCode.INCOMPLETE_ATTEMPT, message, details);
  }
  static feedbackInvalid(message: string) {
    return new AppError(ErrorCode.FEEDBACK_INVALID, message);
  }
}
