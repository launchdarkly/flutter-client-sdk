/// The messages that the adapter and the browser entity exchange over the
/// websocket. Every message is a JSON object.
///
/// The browser sends one `hello` message when it is ready. It lists the
/// contract test capabilities of the SDK in the browser.
///
/// The adapter sends a request with an `id` and an `op`. The browser answers
/// with a response that has the same `id`.
library;

/// The path that the browser connects to.
const String websocketPath = '/ws';

/// The `type` of the first message from the browser.
const String helloType = 'hello';

/// Creates a client. The request `body` is the harness configuration.
/// The response has the `clientId` of the new client.
const String createOp = 'create';

/// Runs a command on a client. The request has a `clientId` and a `body`.
/// The response has a `body`.
const String commandOp = 'command';

/// Closes a client. The request has a `clientId`.
const String deleteOp = 'delete';
