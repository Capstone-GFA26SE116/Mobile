"""Shrink a VRM (GLB) by downscaling textures larger than MAX_SIZE.

Usage (needs Pillow):  python3 shrink_vrm.py ../model.vrm ../model.vrm [--max 1024]

Only image data changes: meshes, morph targets, and the VRM JSON extensions are copied as-is.
The binary buffer is rebuilt so every bufferView keeps its order, with 4-byte alignment.
"""
import argparse
import io
import json
import struct

from PIL import Image

GLB_MAGIC = b'glTF'
CHUNK_JSON = b'JSON'
CHUNK_BIN = b'BIN\x00'


def read_glb(path):
    data = open(path, 'rb').read()
    magic, version, _ = struct.unpack('<4sII', data[:12])
    if magic != GLB_MAGIC or version != 2:
        raise SystemExit(f'{path} is not a glTF 2.0 binary')
    chunks = {}
    offset = 12
    while offset < len(data):
        length, kind = struct.unpack('<I4s', data[offset:offset + 8])
        chunks[kind] = data[offset + 8:offset + 8 + length]
        offset += 8 + length
    return json.loads(chunks[CHUNK_JSON]), chunks[CHUNK_BIN]


def pad(data, fill):
    return data + fill * (-len(data) % 4)


def write_glb(path, gltf, binary):
    json_chunk = pad(json.dumps(gltf, ensure_ascii=False, separators=(',', ':')).encode(), b' ')
    bin_chunk = pad(binary, b'\x00')
    total = 12 + 8 + len(json_chunk) + 8 + len(bin_chunk)
    with open(path, 'wb') as f:
        f.write(struct.pack('<4sII', GLB_MAGIC, 2, total))
        f.write(struct.pack('<I4s', len(json_chunk), CHUNK_JSON) + json_chunk)
        f.write(struct.pack('<I4s', len(bin_chunk), CHUNK_BIN) + bin_chunk)


def downscale(data, mime, max_size):
    image = Image.open(io.BytesIO(data))
    if max(image.size) <= max_size:
        return None
    scale = max_size / max(image.size)
    size = (round(image.width * scale), round(image.height * scale))
    out = io.BytesIO()
    image.resize(size, Image.LANCZOS).save(out, format='PNG' if mime == 'image/png' else 'JPEG',
                                          **({'optimize': True} if mime == 'image/png' else {'quality': 90}))
    print(f'  {image.size[0]}x{image.size[1]} -> {size[0]}x{size[1]}: '
          f'{len(data) // 1024} KB -> {out.tell() // 1024} KB')
    return out.getvalue()


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('src')
    parser.add_argument('dst')
    parser.add_argument('--max', type=int, default=1024)
    args = parser.parse_args()

    gltf, binary = read_glb(args.src)
    replaced = {}
    for image in gltf.get('images', []):
        if 'bufferView' not in image:
            continue
        view = gltf['bufferViews'][image['bufferView']]
        start = view.get('byteOffset', 0)
        smaller = downscale(binary[start:start + view['byteLength']], image['mimeType'], args.max)
        if smaller is not None:
            replaced[image['bufferView']] = smaller

    rebuilt = bytearray()
    for index, view in enumerate(gltf['bufferViews']):
        start = view.get('byteOffset', 0)
        chunk = replaced.get(index, binary[start:start + view['byteLength']])
        rebuilt += b'\x00' * (-len(rebuilt) % 4)
        view['byteOffset'] = len(rebuilt)
        view['byteLength'] = len(chunk)
        rebuilt += chunk
    gltf['buffers'][0]['byteLength'] = len(rebuilt)

    write_glb(args.dst, gltf, bytes(rebuilt))


if __name__ == '__main__':
    main()
