/** Hide retrieval metadata in displayed/copied answers, including streamed tags. */
export function cleanAnswerText(text: string): string {
  return text
    .replace(/[ \t]*\[(?:Source|Chunk)\s+[^\]\r\n]*\]/gi, '')
    .replace(/[ \t]*\[\d+\]\((?:#source-|source:)[^)]*\)/g, '')
    .replace(/[ \t]*\[(?:S(?:o(?:u(?:r(?:c(?:e)?)?)?)?)?|C(?:h(?:u(?:n(?:k)?)?)?)?)(?:\s+[^\]\r\n]*)?$/i, '');
}
