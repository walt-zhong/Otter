# Otter 页面模版

生成 Otter 页面时，只输出一份 JSON 对象。模版描述结构，数据放在另一份 JSON 里。不要输出 XML，不要解释，不要加注释。

示例页面见 `Demo/src/main/assets/templates/`。

## 根对象

```json
{
  "layout": {},
  "events": {}
}
```

`layout` 必填，且只有一个节点。多个区块外面套 `column` 或 `row`。没有点击动作时不要写 `events`。

## 节点

字段顺序固定为：`type`、`id`、该类型自己的内容字段、`layout`、`style`、`onClick`，最后才是 `children` 或 `item`。没有的字段不要写，不要写 `null`。

```json
{
  "type": "text",
  "id": "title",
  "text": "$title",
  "layout": { "width": "fill", "height": "wrap" },
  "style": { "color": "#222222", "fontSize": 16, "align": "start" },
  "onClick": ["openDetail"]
}
```

`id` 用字母或下划线开头，后面只含字母、数字、下划线。同一份模版里不要重复。事件的 `target` 和 `list` 必须有 `id`。

## layout

每个节点都必须有 `layout.width` 和 `layout.height`。

| 值 | 含义 |
| --- | --- |
| 数字 | dp，例如 `16`、`0.5` |
| `"fill"` | 铺满父节点 |
| `"wrap"` | 包住内容 |

`padding` 可以是一个数字，表示四边相同；也可以是对象，只写需要的边：`start`、`end`、`top`、`bottom`。没写的边是 0。

只有 `column` 和 `row` 可以写 `justify`、`align`：

| 字段 | 取值 |
| --- | --- |
| `justify` | `start` `center` `end` `spaceBetween` `spaceAround` `spaceEvenly` |
| `align` | `start` `center` `end` `baseline` `stretch` |

## style

所有节点都可以写：

- `background`：`"#RGB"`、`"#RRGGBB"`、`"#AARRGGBB"`、`"transparent"`，或以 `$` 开头的表达式。渐变写成：

```json
{ "direction": "bottom", "colors": ["#8b572a", "#f5a623"] }
```

`direction` 只能是 `bottom`、`top`、`left`、`right`、`topLeft`、`topRight`、`bottomLeft`、`bottomRight`。`colors` 至少两个，按顺序均匀分布。不要写百分比。

- `radius`：数字表示四角相同。四角分开时用 `topStart`、`topEnd`、`bottomEnd`、`bottomStart`，单位 dp。
- `border`：必须同时有 `color` 和 `width`。`width` 是 dp。

`text` 还可以写 `color`、`fontSize`、`align`（`start` `center` `end`）。

`progress` 还可以写 `track`（底色）和 `bar`（进度颜色）。

## 八种 type

### column / row

竖排或横排。子节点放在 `children` 数组里。不要写 `item`。

### text

必填 `text`。可以是普通字符串，或以 `$` 开头的表达式。`fontSize` 缺省 12，`color` 缺省 `#000000`。

### image

必填 `src`。三种写法：

- `"https://..."` 或 `"http://..."`
- `"res:ic_nav"`，对应 drawable 资源名
- `"$img"`，从数据里取地址

图片按居中裁剪显示。不要写 `local:`。

### spacer

只用来占空或画分割线。分割线用很小的高度加背景色，例如 `"height": 0.5`、`"background": "#D3D3D3"`。

### list

必填 `id`、`data`、`item`。`data` 必须是 `$` 开头的表达式，求值结果是对象数组。`direction` 是 `horizontal` 或 `vertical`，缺省 `vertical`。`gap` 是项与项之间的 dp 间距，最后一项后面不加。

`item` 是单项模版，不是 `children`。单项里面的 `$字段` 读这一项的数据。

```json
{
  "type": "list",
  "id": "feed",
  "data": "$items",
  "direction": "vertical",
  "gap": 12,
  "layout": { "width": "fill", "height": 240 },
  "item": {
    "type": "text",
    "id": "feed_title",
    "text": "$title",
    "layout": { "width": "fill", "height": "wrap" }
  }
}
```

### progress

`from` 和 `to` 是 0 到 1 的比例，可以是数字或 `$` 表达式。进度从 `from` 画到 `to`。`animate` 缺省 `false`。缺省底色是灰色，进度色是红色；需要指定时写 `style.track` 和 `style.bar`。

```json
{
  "type": "progress",
  "layout": { "width": 80, "height": 7 },
  "from": "$start",
  "to": "$end",
  "animate": false,
  "style": { "track": "#cccccc", "bar": "#ffd700" }
}
```

### lottie

必填 `src`。网络地址用 `https://`。包内动画写成 `"assets:animation/lottie-sunny"`，不要自己加 `.json`。

`repeat` 是 `"infinite"` 或非负整数，缺省 `"infinite"`。`mode` 是 `restart` 或 `reverse`，缺省 `restart`。`autoPlay` 缺省 `true`。

## 数据

页面数据是模版外面的一份 JSON。模版里用 `$字段名` 取值，字段名和数据 key 一致。

```json
{
  "title": "今天",
  "items": [{ "title": "第一条" }]
}
```

列表的 `data` 指向数组。数组里的对象字段，只能在对应 `item` 里用 `$` 读取。

事件里的 `message`、`value`、`text` 也可以写 `$` 表达式。比较表达式沿用现有写法，例如 `"$week != null ? $week : '暂无'"`。不要发明新的函数或脚本。

## events

`events` 的 key 是事件名，规则和 `id` 相同。节点用 `"onClick": ["事件名"]` 引用，可以写多个，按数组顺序执行。引用的事件必须存在。`onClick` 不要写成空数组。

只有三种动作。

```json
"events": {
  "tip": { "action": "toast", "message": "$toastMsg" },
  "rename": { "action": "setText", "target": "title", "value": "已更新" },
  "restyle": {
    "action": "setTextStyle",
    "target": "title",
    "fontSize": 14,
    "color": "#cccccc",
    "text": "已更新"
  }
}
```

- `toast` 必填 `message`。
- `setText` 必填 `target` 和 `value`。`target` 是节点 `id`，必须出现在这份模版里。
- `setTextStyle` 必填 `target`，并且 `fontSize`、`color`、`text` 至少写一个。没写的项保持原样。

## 不要写的东西

下面任何一项都会解析失败，或者运行时没有效果：

- XML、注释、`px`、`pt`、`match_parent`、`wrap_content`、`fun{}`
- `props`、`style` 以外的嵌套分组
- `children` 写在 `column` / `row` 之外
- `item` 写在 `list` 之外
- `local:` 图片地址
- 颜色名，例如 `red`、`white`。只用十六进制或 `transparent`
- 渐变停靠百分比
- 输入框、页面跳转、网络请求、开关、Tab、底部导航
- 未知 `type` 或未知字段

## 完整例子

```json
{
  "layout": {
    "type": "column",
    "id": "page",
    "layout": {
      "width": "fill",
      "height": "wrap",
      "padding": 16,
      "align": "center"
    },
    "style": { "background": "#ffffff" },
    "children": [
      {
        "type": "text",
        "id": "headline",
        "text": "$headline",
        "layout": { "width": "fill", "height": "wrap" },
        "style": { "color": "#222222", "fontSize": 18, "align": "start" },
        "onClick": ["rename"]
      },
      {
        "type": "spacer",
        "layout": { "width": "fill", "height": 8 }
      },
      {
        "type": "image",
        "id": "cover",
        "src": "$cover",
        "layout": { "width": "fill", "height": 180 },
        "style": { "radius": 12 }
      }
    ]
  },
  "events": {
    "rename": { "action": "setText", "target": "headline", "value": "已打开" }
  }
}
```

## 输出前检查

1. 根上只有 `layout`，有点击才加 `events`。
2. 每个节点都有 `type`、`layout.width`、`layout.height`。
3. 内容字段只放在对应类型上，视觉字段只放在 `style`，尺寸和对齐只放在 `layout`。
4. 数字尺寸没有单位。颜色是十六进制或 `transparent`。
5. 每个 `onClick` 名字都能在 `events` 里找到，每个 `target` 都能在节点 `id` 里找到。
6. `list` 使用 `item`，`data` 以 `$` 开头。
7. 没有空对象、空数组和 `null`。
