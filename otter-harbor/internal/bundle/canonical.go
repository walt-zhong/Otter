package bundle

import (
	"crypto/sha256"
	"fmt"
)

var ContentOrder = []string{
	"routes.json",
	"templates/list.json",
	"templates/detail.json",
	"data/list.json",
	"data/detail.json",
}

const ManifestName = "manifest.json"

func Names() []string {
	out := append([]string{}, ContentOrder...)
	return append(out, ManifestName)
}

func Digest(files map[string][]byte) ([]byte, error) {
	h := sha256.New()
	for _, name := range ContentOrder {
		body, ok := files[name]
		if !ok {
			return nil, fmt.Errorf("missing %s", name)
		}
		if _, err := fmt.Fprintf(h, "%s\n%d\n", name, len(body)); err != nil {
			return nil, err
		}
		if _, err := h.Write(body); err != nil {
			return nil, err
		}
	}
	return h.Sum(nil), nil
}
