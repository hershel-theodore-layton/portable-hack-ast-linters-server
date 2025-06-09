/** portable-hack-ast-linters-server is MIT licensed, see /LICENSE. */
namespace HTL\PhaLintersServer\_Private;

final class SourceFile {
  private function __construct(
    private string $filePath,
    private string $sourceText,
  )[] {}

  public static function fromPathAndSourceText(
    string $path,
    string $source_text,
  )[]: this {
    return new static($path, $source_text);
  }

  public function getPath()[]: string {
    return $this->filePath;
  }

  public function getSourceText()[]: string {
    return $this->sourceText;
  }
}
