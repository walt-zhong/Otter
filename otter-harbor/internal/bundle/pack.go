package bundle

import (
	"archive/zip"
	"bytes"
	"crypto/ed25519"
	"encoding/base64"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"hash/crc32"
	"io"
	"time"
)

const (
	maxFile = 256 * 1024
	maxZip  = 1024 * 1024
)

type Manifest struct {
	ID        string `json:"id"`
	Intent    string `json:"intent"`
	Sample    bool   `json:"sample"`
	CreatedAt string `json:"createdAt"`
	Hash      string `json:"hash"`
	Alg       string `json:"alg"`
	Signature string `json:"signature"`
}

type Files struct {
	Routes         []byte
	ListTemplate   []byte
	DetailTemplate []byte
	ListData       []byte
	DetailData     []byte
}

func (f Files) Map() map[string][]byte {
	return map[string][]byte{
		"routes.json":           f.Routes,
		"templates/list.json":   f.ListTemplate,
		"templates/detail.json": f.DetailTemplate,
		"data/list.json":        f.ListData,
		"data/detail.json":      f.DetailData,
	}
}

func Pack(id, intent string, sample bool, created time.Time, files Files, priv ed25519.PrivateKey) ([]byte, Manifest, error) {
	content := files.Map()
	sum := 0
	for name, body := range content {
		if len(body) > maxFile {
			return nil, Manifest{}, fmt.Errorf("%s exceeds 256 KiB", name)
		}
		sum += len(body)
	}
	digest, err := Digest(content)
	if err != nil {
		return nil, Manifest{}, err
	}
	sig := ed25519.Sign(priv, digest)
	manifest := Manifest{
		ID:        id,
		Intent:    intent,
		Sample:    sample,
		CreatedAt: created.UTC().Format(time.RFC3339),
		Hash:      hex.EncodeToString(digest),
		Alg:       "ed25519",
		Signature: base64.StdEncoding.EncodeToString(sig),
	}
	rawManifest, err := json.Marshal(manifest)
	if err != nil {
		return nil, Manifest{}, err
	}
	if len(rawManifest) > maxFile {
		return nil, Manifest{}, fmt.Errorf("manifest exceeds 256 KiB")
	}
	sum += len(rawManifest)
	if sum > maxZip {
		return nil, Manifest{}, fmt.Errorf("bundle exceeds 1 MiB")
	}
	content[ManifestName] = rawManifest
	packed, err := writeStore(content)
	if err != nil {
		return nil, Manifest{}, err
	}
	return packed, manifest, nil
}

func writeStore(files map[string][]byte) ([]byte, error) {
	var buf bytes.Buffer
	zw := zip.NewWriter(&buf)
	for _, name := range Names() {
		body, ok := files[name]
		if !ok {
			return nil, fmt.Errorf("missing %s", name)
		}
		hdr := &zip.FileHeader{Name: name, Method: zip.Store}
		hdr.SetMode(0o644)
		hdr.CRC32 = crc32.ChecksumIEEE(body)
		hdr.CompressedSize64 = uint64(len(body))
		hdr.UncompressedSize64 = uint64(len(body))
		// CreateHeader always sets the data-descriptor flag. Android ZipInputStream
		// then treats the next entry as invalid. Put the sizes in the local header.
		w, err := zw.CreateRaw(hdr)
		if err != nil {
			return nil, err
		}
		if _, err := w.Write(body); err != nil {
			return nil, err
		}
	}
	if err := zw.Close(); err != nil {
		return nil, err
	}
	return buf.Bytes(), nil
}

type Opened struct {
	Manifest Manifest
	Files    map[string][]byte
}

func Open(raw []byte, pub ed25519.PublicKey) (Opened, error) {
	zr, err := zip.NewReader(bytes.NewReader(raw), int64(len(raw)))
	if err != nil {
		return Opened{}, err
	}
	if len(zr.File) != len(Names()) {
		return Opened{}, fmt.Errorf("want %d entries", len(Names()))
	}
	files := map[string][]byte{}
	allowed := map[string]struct{}{}
	for _, name := range Names() {
		allowed[name] = struct{}{}
	}
	sum := 0
	for _, file := range zr.File {
		if _, ok := allowed[file.Name]; !ok || file.FileInfo().IsDir() {
			return Opened{}, fmt.Errorf("rejected entry %s", file.Name)
		}
		if _, dup := files[file.Name]; dup {
			return Opened{}, fmt.Errorf("duplicate %s", file.Name)
		}
		if file.Method != zip.Store {
			return Opened{}, fmt.Errorf("%s is compressed", file.Name)
		}
		if file.Mode()&0o111 != 0 {
			return Opened{}, fmt.Errorf("%s is executable", file.Name)
		}
		if file.UncompressedSize64 > maxFile {
			return Opened{}, fmt.Errorf("%s too large", file.Name)
		}
		rc, err := file.Open()
		if err != nil {
			return Opened{}, err
		}
		body, err := io.ReadAll(io.LimitReader(rc, maxFile+1))
		rc.Close()
		if err != nil {
			return Opened{}, err
		}
		if len(body) > maxFile {
			return Opened{}, fmt.Errorf("%s too large", file.Name)
		}
		files[file.Name] = body
		sum += len(body)
	}
	if sum > maxZip {
		return Opened{}, fmt.Errorf("bundle too large")
	}
	for _, name := range Names() {
		if _, ok := files[name]; !ok {
			return Opened{}, fmt.Errorf("missing %s", name)
		}
	}
	var manifest Manifest
	if err := json.Unmarshal(files[ManifestName], &manifest); err != nil {
		return Opened{}, err
	}
	digest, err := Digest(files)
	if err != nil {
		return Opened{}, err
	}
	if hex.EncodeToString(digest) != manifest.Hash {
		return Opened{}, fmt.Errorf("hash mismatch")
	}
	sig, err := base64.StdEncoding.DecodeString(manifest.Signature)
	if err != nil {
		return Opened{}, err
	}
	if !ed25519.Verify(pub, digest, sig) {
		return Opened{}, fmt.Errorf("bad signature")
	}
	return Opened{Manifest: manifest, Files: files}, nil
}
