package generate

import "encoding/json"

const (
	coverClear   = "https://images.unsplash.com/photo-1620786963525-4a74f1697a46?auto=format&fit=crop&w=800&h=1000&fp-x=0.08&fp-y=0.45&q=80"
	coverMatte   = "https://images.unsplash.com/photo-1759588071796-7648b7569d59?auto=format&fit=crop&w=800&h=1000&q=80"
	coverLeather = "https://images.unsplash.com/photo-1620786963525-4a74f1697a46?auto=format&fit=crop&w=800&h=1000&q=80"
)

type product struct {
	Title string `json:"title"`
	Price string `json:"price"`
	Cover string `json:"cover"`
	Note  string `json:"note"`
}

func offlineShopping(query string) (map[string]any, map[string]any, map[string]any, map[string]any) {
	_ = query
	list := shoppingList()
	detail := shoppingDetail()
	data := map[string]any{
		"sample":      true,
		"sampleLabel": "示例",
		"products": []product{
			{Title: "透明壳", Price: "29", Cover: coverClear, Note: "全透明，能看见后面的机身"},
			{Title: "磨砂壳", Price: "39", Cover: coverMatte, Note: "磨砂黑，背面是一圈圈纹路"},
			{Title: "皮革壳", Price: "49", Cover: coverLeather, Note: "棕色皮革，背面有一个卡槽"},
			{Title: "透明防摔壳", Price: "35", Cover: coverClear, Note: "边框加厚，背面仍然透明"},
			{Title: "磨砂超薄壳", Price: "42", Cover: coverMatte, Note: "同样的磨砂黑，更贴机身"},
			{Title: "皮革卡包壳", Price: "59", Cover: coverLeather, Note: "棕色皮革，卡槽可以放一张卡"},
			{Title: "透明软壳", Price: "25", Cover: coverClear, Note: "软边透明，能看见机身颜色"},
			{Title: "磨砂纹路壳", Price: "45", Cover: coverMatte, Note: "磨砂黑，纹路从中心散开"},
		},
	}
	detailData := map[string]any{
		"title": "",
		"price": "",
		"cover": coverClear,
		"note":  "",
	}
	return list, detail, data, detailData
}

func offlineClarify() (map[string]any, map[string]any, map[string]any, map[string]any) {
	list := map[string]any{
		"layout": map[string]any{
			"type":   "column",
			"id":     "page",
			"layout": box("fill", "fill"),
			"children": []any{
				textNode("hint", "$message", ""),
			},
		},
	}
	detail := map[string]any{
		"layout": map[string]any{
			"type":   "column",
			"id":     "detail",
			"layout": box("fill", "fill"),
			"children": []any{
				textNode("back", "返回", "goBack"),
			},
		},
		"events": map[string]any{
			"goBack": map[string]any{"action": "back"},
		},
	}
	data := map[string]any{
		"message":  "请说明想买的商品，例如：买个手机壳",
		"products": []product{},
	}
	return list, detail, data, map[string]any{}
}

func shoppingList() map[string]any {
	return map[string]any{
		"layout": map[string]any{
			"type":   "column",
			"id":     "page",
			"layout": map[string]any{"width": "fill", "height": "fill", "padding": map[string]any{"top": 4, "bottom": 8}},
			"style":  map[string]any{"background": "#F7F4EF"},
			"children": []any{
				map[string]any{
					"type":   "row",
					"layout": map[string]any{"width": "fill", "height": "wrap", "align": "center", "margin": edge(16, 16, 12, 0)},
					"children": []any{
						styledText("heading", "手机壳", map[string]any{"color": "#1F1A17", "fontSize": 22, "fontWeight": "bold"}, size("wrap", "wrap"), ""),
						map[string]any{"type": "spacer", "layout": map[string]any{"width": 8, "height": 8}},
						styledText("badge", "$sampleLabel", map[string]any{"color": "#1F6F6A", "fontSize": 12, "background": "#E7F3F1", "radius": 10}, map[string]any{"width": "wrap", "height": "wrap", "padding": edge(8, 8, 3, 3)}, ""),
					},
				},
				styledText("", "点一张卡片看详情", map[string]any{"color": "#8A8178", "fontSize": 13}, map[string]any{"width": "fill", "height": "wrap", "margin": edge(16, 16, 4, 12)}, ""),
				map[string]any{
					"type":   "list",
					"id":     "goods",
					"data":   "$products",
					"gap":    12,
					"layout": map[string]any{"width": "fill", "height": "fill"},
					"item":   productCard(),
				},
			},
		},
		"events": map[string]any{
			"openDetail": map[string]any{
				"action": "open",
				"page":   "detail",
				"params": map[string]any{
					"title": "$title",
					"price": "$price",
					"cover": "$cover",
					"note":  "$note",
				},
			},
		},
	}
}

func productCard() map[string]any {
	return map[string]any{
		"type":    "column",
		"layout":  map[string]any{"width": "fill", "height": "wrap", "padding": 12, "margin": edge(16, 16, 0, 0)},
		"style":   map[string]any{"background": "#FFFFFF", "radius": 16, "border": map[string]any{"color": "#E6DDD2", "width": 1}},
		"onClick": []string{"openDetail"},
		"children": []any{
			map[string]any{
				"type":   "row",
				"layout": map[string]any{"width": "fill", "height": "wrap", "align": "center"},
				"children": []any{
					coverImage("thumb", "$cover", 96, 96),
					map[string]any{"type": "spacer", "layout": map[string]any{"width": 12, "height": 12}},
					map[string]any{
						"type":   "column",
						"layout": map[string]any{"width": "fill", "height": "wrap"},
						"children": []any{
							styledText("", "$title", map[string]any{"color": "#1F1A17", "fontSize": 17, "fontWeight": "bold"}, size("fill", "wrap"), ""),
							styledText("", "$note", map[string]any{"color": "#8A8178", "fontSize": 13}, map[string]any{"width": "fill", "height": "wrap", "margin": edge(0, 0, 4, 0)}, ""),
							map[string]any{
								"type":   "row",
								"layout": map[string]any{"width": "fill", "height": "wrap", "align": "end", "margin": edge(0, 0, 10, 0)},
								"children": []any{
									styledText("", "¥", map[string]any{"color": "#C45C26", "fontSize": 13}, size("wrap", "wrap"), ""),
									styledText("", "$price", map[string]any{"color": "#C45C26", "fontSize": 18, "fontWeight": "bold"}, map[string]any{"width": "wrap", "height": "wrap", "margin": edge(2, 0, 0, 0)}, ""),
								},
							},
						},
					},
				},
			},
		},
	}
}

func shoppingDetail() map[string]any {
	return map[string]any{
		"layout": map[string]any{
			"type":   "column",
			"id":     "detail",
			"scroll": true,
			"layout": map[string]any{"width": "fill", "height": "fill", "padding": 16},
			"style":  map[string]any{"background": "#F7F4EF"},
			"children": []any{
				styledText("back", "返回", map[string]any{"color": "#1F6F6A", "fontSize": 15}, size("wrap", "wrap"), "goBack"),
				detailCover(),
				styledText("title", "$title", map[string]any{"color": "#1F1A17", "fontSize": 22, "fontWeight": "bold"}, map[string]any{"width": "fill", "height": "wrap", "margin": edge(0, 0, 16, 0)}, ""),
				styledText("note", "$note", map[string]any{"color": "#8A8178", "fontSize": 14}, map[string]any{"width": "fill", "height": "wrap", "margin": edge(0, 0, 6, 0)}, ""),
				map[string]any{
					"type":   "row",
					"layout": map[string]any{"width": "fill", "height": "wrap", "align": "end", "margin": edge(0, 0, 14, 0)},
					"children": []any{
						styledText("", "¥", map[string]any{"color": "#C45C26", "fontSize": 16}, size("wrap", "wrap"), ""),
						styledText("price", "$price", map[string]any{"color": "#C45C26", "fontSize": 28, "fontWeight": "bold"}, map[string]any{"width": "wrap", "height": "wrap", "margin": edge(2, 0, 0, 0)}, ""),
					},
				},
				styledText("", "加入示例", map[string]any{"color": "#FFFCF8", "fontSize": 15, "align": "center", "background": "#1F1A17", "radius": 14}, map[string]any{"width": "fill", "height": "wrap", "margin": edge(0, 0, 24, 0), "padding": edge(0, 0, 14, 14)}, "addSample"),
			},
		},
		"events": map[string]any{
			"goBack":    map[string]any{"action": "back"},
			"addSample": map[string]any{"action": "toast", "message": "这是示例商品，先不下单"},
		},
	}
}

func box(width string, height any) map[string]any {
	return map[string]any{"width": width, "height": height, "padding": 16}
}

func size(width string, height any) map[string]any {
	return map[string]any{"width": width, "height": height}
}

func edge(start, end, top, bottom int) map[string]any {
	return map[string]any{"start": start, "end": end, "top": top, "bottom": bottom}
}

func textNode(id, value, click string) map[string]any {
	return styledText(id, value, nil, size("fill", "wrap"), click)
}

func styledText(id, value string, style, layout map[string]any, click string) map[string]any {
	node := map[string]any{
		"type":   "text",
		"text":   value,
		"layout": layout,
	}
	if len(style) > 0 {
		node["style"] = style
	}
	if id != "" {
		node["id"] = id
	}
	if click != "" {
		node["onClick"] = []string{click}
	}
	return node
}

func detailCover() map[string]any {
	node := coverImage("cover", "$cover", "fill", 200)
	node["layout"].(map[string]any)["margin"] = edge(0, 0, 12, 0)
	style := node["style"].(map[string]any)
	style["fit"] = "cover"
	style["radius"] = 16
	return node
}

func coverImage(id, src string, width any, height int) map[string]any {
	return map[string]any{
		"type":   "image",
		"id":     id,
		"src":    src,
		"layout": map[string]any{"width": width, "height": height},
		"style": map[string]any{
			"fit":         "contain",
			"background":  "#F3EFE7",
			"placeholder": "#E7D3C3",
			"radius":      12,
		},
	}
}

func mustJSON(v any) []byte {
	raw, err := json.Marshal(v)
	if err != nil {
		panic(err)
	}
	return raw
}

func canonicalRoutes() []byte {
	return mustJSON(map[string]any{
		"start": "list",
		"pages": map[string]any{
			"list": map[string]any{
				"template": "templates/list.json",
				"data":     "data/list.json",
			},
			"detail": map[string]any{
				"template": "templates/detail.json",
				"data":     "data/detail.json",
			},
		},
	})
}
