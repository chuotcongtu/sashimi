class IdentifierError < RuntimeError; end

RESCUABLE_EXCEPTIONS = [CanCan::AccessDenied,
                        JWT::VerificationError,
                        JSON::ParserError,
                        ActiveRecord::RecordNotFound,
                        AbstractController::ActionNotFound,
                        ActionController::RoutingError,
                        ActionController::ParameterMissing,
                        ActionController::UnpermittedParameters,
                        NoMethodError]