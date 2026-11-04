package intent

import "strings"

const (
	Shopping = "shopping.browse"
	Clarify  = "clarify"
)

var shoppingNeedles = []string{"买", "商品", "购物", "下单", "手机壳"}

func Classify(query string) string {
	for _, needle := range shoppingNeedles {
		if strings.Contains(query, needle) {
			return Shopping
		}
	}
	return Clarify
}
