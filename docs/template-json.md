# Otter 页面模版

生成 Otter 页面时，只输出一份 JSON 对象。模版描述结构，数据放在另一份 JSON 里。不要输出 XML，不要解释，不要加注释。

给人看的节点说明在 [components.md](components.md)。示例页面在 `Demo/src/main/assets/templates/`。

## 根对象

```json
{
  "layout": {},
  "events": {}
}
```

`layout` 必填，且只有一个节点。多个区块外面套 `column` 或 `row`。没有 `onClick` 或 `onChange` 时不要写 `events`。

## 节点

字段顺序固定为：`type`、`id`、该类型自己的内容字段（`column` 的 `scroll` 也写在这里）、`layout`、`style`、`visible`、`onClick`、`onChange`，最后才是 `children` 或 `item`。没有的字段不要写，不要写 `null`。

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

任何节点都可以写 `visible` 和 `onChange`。

`visible` 是布尔值，或以 `$` 开头的表达式。`false` 时这个节点不参与布局。缺省显示。

`onChange` 和 `onClick` 一样，是事件名数组，不能是空数组，名字必须在 `events` 里。多个名字按数组顺序执行。

只有 `column` 可以写 `scroll`，而且只能是布尔值，不能写表达式。`true` 时这一列是视口，子节点高出视口就可以在列里滚动。缺省 `false`。

## layout

每个节点都必须有 `layout.width` 和 `layout.height`。

| 值 | 含义 |
| --- | --- |
| 数字 | dp，例如 `16`、`0.5` |
| `"fill"` | 铺满父节点 |
| `"wrap"` | 包住内容 |

`padding` 可以是一个数字，表示四边相同；也可以是对象，只写需要的边：`start`、`end`、`top`、`bottom`。没写的边是 0。`margin` 同样写法。

`minWidth`、`minHeight`、`maxWidth`、`maxHeight` 的写法和 `width`、`height` 一样：数字、`"fill"` 或 `"wrap"`。

`aspectRatio` 是正数。

`alignSelf` 任何节点都能写：`start`、`center`、`end`、`stretch`。

只有 `column` 和 `row` 可以写 `justify`、`align`、`wrap`：

| 字段 | 取值 |
| --- | --- |
| `justify` | `start` `center` `end` `spaceBetween` `spaceAround` `spaceEvenly` |
| `align` | `start` `center` `end` `baseline` `stretch` |
| `wrap` | 布尔。`true` 换行，`false` 不换行。缺省不换行 |

## style

所有节点都可以写：

- `background`：`"#RGB"`、`"#RRGGBB"`、`"#AARRGGBB"`、`"transparent"`，或以 `$` 开头的表达式。渐变写成：

```json
{ "direction": "bottom", "colors": ["#8b572a", "#f5a623"] }
```

`direction` 只能是 `bottom`、`top`、`left`、`right`、`topLeft`、`topRight`、`bottomLeft`、`bottomRight`。`colors` 至少两个，按顺序均匀分布。不要写百分比。

- `radius`：数字表示四角相同。四角分开时用 `topStart`、`topEnd`、`bottomEnd`、`bottomStart`，单位 dp。
- `border`：必须同时有 `color` 和 `width`。`width` 是 dp。

`text` 还可以写 `color`、`fontSize`、`align`（`start` `center` `end`）、`maxLines`（正整数）、`ellipsis`（布尔）、`fontWeight`（`regular` `medium` `bold`）。不写 `ellipsis` 就不加省略号。不写 `fontWeight` 就是 `regular`。

`image` 还可以写 `fit`（`cover` `contain` `fill`）和 `placeholder`。`placeholder` 用和背景一样的纯色：`#RGB`、`#RRGGBB`、`#AARRGGBB`、`transparent`，或以 `$` 开头。不要写渐变。

`input` 还可以写 `lines`（正整数），放在节点上或 `style` 里都可以。不写就是一行。`style` 里还可以写 `color`、`fontSize`、`align`、`hintColor`。

`progress` 还可以写 `track`（底色）和 `bar`（进度颜色）。

## 节点类型

### column / row

竖排或横排。子节点放在 `children` 数组里。不要写 `item`。`column` 可以写 `scroll`。`column` 和 `row` 可以写 `layout.wrap`。

### text

必填 `text`。可以是普通字符串，或以 `$` 开头的表达式。`fontSize` 缺省 12，`color` 缺省 `#000000`。

### image

必填 `src`。三种写法：

- `"https://..."` 或 `"http://..."`
- `"res:ic_nav"`，对应 drawable 资源名
- `"$img"`，从数据里取地址

不写 `fit` 时按 `cover` 居中裁剪。需要别的适应方式时写 `style.fit`：`cover`、`contain`、`fill`。不要写 `local:`。

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

### input

可选 `value`、`hint`、`keyboard`、`maxLength`、`lines`。`keyboard` 是 `text`、`number`、`password`、`email`、`phone`，缺省 `text`。`maxLength` 是非负整数。`lines` 是正整数，也可以写在 `style.lines`，缺省一行。

### checkbox / switch

可选 `checked`、`label`。`checked` 是布尔值或以 `$` 开头，缺省 `false`。

### radio

和 checkbox 一样，另外必填 `group`。`group` 是标识符或以 `$` 开头。

## 数据

页面数据是模版外面的一份 JSON。模版里用 `$字段名` 取值，字段名和数据 key 一致。

```json
{
  "title": "今天",
  "items": [{ "title": "第一条" }]
}
```

列表的 `data` 指向数组。数组里的对象字段，只能在对应 `item` 里用 `$` 读取。

事件里的 `message`、`value`、`text`、`page`、`index`、`name` 也可以写 `$` 表达式。比较表达式沿用现有写法，例如 `"$week != null ? $week : '暂无'"`。不要发明新的函数或脚本。

## events

`events` 的 key 是事件名，规则和 `id` 相同。节点用 `"onClick": ["事件名"]` 或 `"onChange": ["事件名"]` 引用，可以写多个，按数组顺序执行。引用的事件必须存在。`onClick` 和 `onChange` 不要写成空数组。

动作只有下面这些。

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
- `setChecked` 必填 `target` 和 `value`。`target` 是一个 id，或 id 数组。`value` 是布尔值或以 `$` 开头。
- `append` 必填 `list`、`from`、`field`、`data`、`item`。`item` 是字符串字段组成的对象。可以再写 `empty`。
- `update` 必填 `list`、`index`、`item`。`index` 是非负整数或以 `$` 开头。`item` 和 `append` 的 `item` 一样。
- `remove` 必填 `list` 和 `index`。`index` 的写法和 `update` 一样。
- `open`、`replace`、`popTo` 必填 `page`。`page` 是页面名或以 `$` 开头。可以再写 `params`。`params` 里的值可以是字符串、数字、布尔、对象或数组。
- `back` 可以只写 `action`，也可以再写和 `open` 一样的 `params`。
- `host` 必填 `name`。`name` 是标识符或以 `$` 开头。可以再写和 `open` 一样的 `params`。
- 权限用这三个 host：`permissionCheck`、`permissionRequest`、`permissionOpenSettings`。`params.capability` 只能是 `camera`、`microphone`、`location.whenInUse`、`photos`、`notifications`。说明文案由宿主写死。结果写回当前页，例如 `cameraStatus`、`cameraStatusText`、`cameraShowSettings`，另外四项用同样的前缀。相册选中后还会写 `photoSrc` 和 `avatar`。

## 不要写的东西

下面任何一项都会解析失败，或者运行时没有效果：

- XML、注释、`px`、`pt`、`match_parent`、`wrap_content`、`fun{}`
- `props`、`style` 以外的嵌套分组
- `children` 写在 `column` / `row` 之外
- `item` 写在 `list` 之外
- `local:` 图片地址
- 颜色名，例如 `red`、`white`。只用十六进制或 `transparent`
- 渐变停靠百分比
- 网络请求、Tab、底部导航、地图、支付、网页。不要写系统权限名，权限走上面的 host
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

1. 根上只有 `layout`，有 `onClick` 或 `onChange` 才加 `events`。
2. 每个节点都有 `type`、`layout.width`、`layout.height`。
3. 内容字段只放在对应类型上，视觉字段只放在 `style`，尺寸和对齐只放在 `layout`。
4. 数字尺寸没有单位。颜色是十六进制或 `transparent`。
5. 每个 `onClick`、`onChange` 名字都能在 `events` 里找到，每个 `target` 和 `list` 都能在节点 `id` 里找到。
6. `list` 使用 `item`，`data` 以 `$` 开头。
7. 没有空对象、空数组和 `null`。
