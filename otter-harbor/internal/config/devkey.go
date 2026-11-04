package config

import (
	"crypto/ed25519"
	"encoding/base64"
)

// 调试密钥只配对 Demo 调试包里的公钥。生产必须设置 OTTER_SIGNING_KEY。
const devPrivateKeyB64 = "pGPzWaBxiDQxhtjmEYJPOikvAtB/JnoV+ArxpdXKnyvury9jy3CipNH9TSc2ZDawvWH6iWgRPXZj+vo9jpKBtQ=="

func DevPrivateKey() ed25519.PrivateKey {
	raw, err := base64.StdEncoding.DecodeString(devPrivateKeyB64)
	if err != nil {
		panic(err)
	}
	if len(raw) != ed25519.PrivateKeySize {
		panic("dev key length")
	}
	return ed25519.PrivateKey(raw)
}
