/** portable-hack-ast-linters-server is MIT licensed, see /LICENSE. */
namespace HTL\PhaLintersServer;

use namespace HH\Lib\IO;

/**
 * If request_error is available, we are in CLI mode.
 * This is a simple check to make sure that the web server
 * does not accidentally expose signing functionality.
 */
function is_likely_cli()[defaults]: bool {
  return IO\request_error() is nonnull;
}
