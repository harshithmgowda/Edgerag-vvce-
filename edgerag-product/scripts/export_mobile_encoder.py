"""Export the exact server encoder plus parity checks. Does not download models."""
import sys, json, hashlib, zipfile, argparse
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'packages/rag-core'))
from src.embedder import get_embedder

def export(output):
    encoder = get_embedder()
    names = ['onnx/model.onnx', 'tokenizer.json']
    files = {name: hashlib.sha256((encoder.directory / name).read_bytes()).hexdigest() for name in names}
    texts = ['E-104: motor overheating at 85°C.', 'The pump is not draining.', 'Café pressure, 中文 test.']
    manifest = {'fingerprint': encoder.fingerprint(), 'files': files,
        'parity_cases': [{'text': text, 'ids': encoder.tokenizer.encode(text).ids, 'vector': encoder.embed_text(text)} for text in texts]}
    with zipfile.ZipFile(output, 'w', zipfile.ZIP_DEFLATED) as bundle:
        for name in names: bundle.write(encoder.directory / name, name)
        bundle.writestr('encoder.json', json.dumps(manifest))
    print(f'Exported compatible MiniLM encoder: {output}')

if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('output', type=Path)
    export(parser.parse_args().output)
