# 组件

模版节点有十二种。`TemplateJsonParser` 只认这些 `type`，`OTViewFactory` 每种造一个 Android 控件。生成时的字段顺序和不能写的东西在 [template-json.md](template-json.md)。每种组件的示例在 `Demo/src/main/assets/templates/<type>/`。

## 每种节点都有的字段

每个节点要有 `type`、`layout.width`、`layout.height`。没有的字段别写，也别写 `null`。

`id` 用字母或下划线开头，后面只含字母、数字、下划线，同一份模版里不重复。事件的 `target`、列表动作的 `list`、要写回页面数据的输入框、要被 `setChecked` 点名的控件，都要有 `id`。

`visible` 是布尔值，或以 `$` 开头。`false` 时这个节点不参与布局。缺省显示。

`onClick` 和 `onChange` 是事件名数组，不能是空数组，名字要在根上的 `events` 里。多个名字按顺序执行。`onChange` 由输入框的文字变化，以及勾选、单选、开关的选中变化触发。

### layout

| 字段 | 谁能写 | 取值 |
| --- | --- | --- |
| `width` `height` | 全部 | dp 数字、`"fill"`、`"wrap"` |
| `minWidth` `minHeight` `maxWidth` `maxHeight` | 全部 | 同上 |
| `padding` `margin` | 全部 | 一个数字表示四边；或只写 `start`、`end`、`top`、`bottom` |
| `grow` | 全部 | 正数，分剩余空间 |
| `aspectRatio` | 全部 | 正数 |
| `alignSelf` | 全部 | `start` `center` `end` `stretch` |
| `justify` | `column` `row` | `start` `center` `end` `spaceBetween` `spaceAround` `spaceEvenly` |
| `align` | `column` `row` | `start` `center` `end` `baseline` `stretch` |
| `wrap` | `column` `row` | 布尔。`true` 时换行 |

数字单位是 dp。Stretch 布局时把 dp 换成像素。`fill` 铺满父节点在这条轴上的空间，`wrap` 包住内容。文字的 `wrap` 高度还会经过 `WrapTextHeight` 测量。

`justify` 管主轴，`align` 管交叉轴。`column` 的主轴是竖直方向，`row` 的主轴是水平方向。

### style

- `background`：`#RGB`、`#RRGGBB`、`#AARRGGBB`、`transparent`，或以 `$` 开头。也可以写 `res:drawable名`，图片按 cover 铺满这一层。写在 `column` 上且图片比这一层高时，上下拖动只移动背景，子节点留在原地。渐变写成对象，`direction` 取 `bottom`、`top`、`left`、`right`、`topLeft`、`topRight`、`bottomLeft`、`bottomRight`，`colors` 至少两个，按顺序均匀分布。
- `radius`：一个数字表示四角相同，单位 dp。分开写时用 `topStart`、`topEnd`、`bottomEnd`、`bottomStart`。
- `border`：同时有 `color` 和 `width`，`width` 是 dp。
- `glass`：只给 `column`、`row`、`spacer`。不要和 `background` 一起写。`"glass": {}` 是标准玻璃。可以写 `style`（`regular` 或 `clear`，缺省 `regular`）、`tint`、`interactive`。`clear` 更透，圆角边缘折得更明显；`regular` 中间有一层薄霜。`tint` 写法和颜色一样，用 `#AARRGGBB`，不写渐变，不写就用这种样式自己的一层薄白。`interactive` 是布尔，按下时这一层更亮。圆角和边框仍用 `radius`、`border`。不要写模糊、高光、阴影。文字、图片、输入框、列表不要写，外面套一层容器。玻璃取的是这一层背后已经画好的画面，子节点保持清晰。Android 13 及以上，圆角边缘会折射背后的颜色；更早的系统只做模糊。背后要有内容，平的纯色上看起来会像一块实心。示例：`templates/glass/glass.json`。

颜色写十六进制或 `transparent`。`red`、`white` 这种名字在解析时会被拒绝。

## column

纵向容器，子节点写在 `children`。控件是 `Column`，继承 `OTAbsoluteLayout`。

`scroll` 只能是布尔值。`true` 时这一列是视口，高出视口的子节点在内部的 `NestedScrollView` 里滚。页面栈会记 `list` 的滚动位置，不记这一列的滚动。

`background` 写成 `res:` 位图、并且图比这一列高时，上下拖动只改背景偏移，子节点留在原地。这种列不要再写 `scroll`，上下拖动会先被背景吃掉。图没有高出这一列时，拖动没有位移。

`style.glass` 写在这一层，垫在子节点下面，文字和图保持清晰。Android 13 及以上，圆角边缘会把背后的画面折进来。

```json
{
  "type": "column",
  "id": "page",
  "scroll": true,
  "layout": {
    "width": "fill",
    "height": "fill",
    "padding": { "start": 20, "end": 20, "top": 12, "bottom": 12 }
  },
  "children": []
}
```

首页列表用 `layout.grow` 吃掉标题下面的高度。示例：`templates/column/column.json`。

## row

横向容器，子节点写在 `children`。控件是 `Row`，同样继承 `OTAbsoluteLayout`。一行放不下时把 `layout.wrap` 设为 `true`。整行要滚，用横向 `list`。

```json
{
  "type": "row",
  "id": "back",
  "layout": { "width": "fill", "height": 36, "align": "center" },
  "onClick": ["goBack"],
  "children": [
    { "type": "image", "src": "res:ic_back", "layout": { "width": 18, "height": 18 } },
    { "type": "spacer", "layout": { "width": 4, "height": 18 } },
    {
      "type": "text",
      "text": "返回",
      "layout": { "width": 40, "height": 20 },
      "style": { "color": "#1F1A17", "fontSize": 14 }
    }
  ]
}
```

点击写在行上时，点到没有自己 `onClick` 的子节点也会落到这行。`style.glass` 同样写在这一层，子节点画在玻璃上面。示例：`templates/row/row.json`。

## text

控件是 `Text`，继承 `AppCompatTextView`。`text` 必填，可以是字符串或 `$` 表达式。

| 字段 | 位置 | 缺省 |
| --- | --- | --- |
| `color` | `style` | `#000000` |
| `fontSize` | `style` | 12 |
| `align` | `style` | 不写则按系统默认。取值 `start` `center` `end` |
| `maxLines` | `style` | 不限制 |
| `ellipsis` | `style` | 不写就不加省略号 |
| `fontWeight` | `style` | `regular`。还可以写 `medium`、`bold` |

`setText` 的 `target` 可以是 `text` 或 `input`。`setTextStyle` 改 `fontSize`、`color`、`text`，至少写一项。这两个动作改的是当前 View。页面栈恢复出来的是原来的数据，不包含这次改动。

```json
{
  "type": "text",
  "id": "headline",
  "text": "$headline",
  "layout": { "width": "fill", "height": "wrap" },
  "style": { "color": "#1F1A17", "fontSize": 22, "fontWeight": "medium", "maxLines": 2, "ellipsis": true }
}
```

示例：`templates/text/text.json`。

## image

控件是 `Image`，继承 `AppCompatImageView`。网络图和 `content:` 由 Glide 加载，`release` 时取消请求。`src` 必填。

| 地址 | 行为 |
| --- | --- |
| `https://` 或 `http://` | Glide 加载 |
| `res:ic_back` | drawable 资源名，不带扩展名 |
| `content:` | 系统选图返回的地址。权限流程写回的 `photoSrc`、`avatar` 用这种 |
| `$cover` | 从数据里取上面任意一种字符串 |

`style.fit` 缺省 `cover`。`cover` 是 `CENTER_CROP`，`contain` 是 `FIT_CENTER`，`fill` 是 `FIT_XY`。`style.placeholder` 是纯色，写法同背景，不写渐变。圆角和边框用公共的 `radius`、`border`。

```json
{
  "type": "image",
  "id": "cover",
  "src": "$cover",
  "layout": { "width": "fill", "height": 180 },
  "style": { "fit": "cover", "radius": 12, "placeholder": "#E7E1D8" }
}
```

示例：`templates/image/image.json`。南市「我的」用同一节点显示选中的头像。

## spacer

一个没有内容的 `View`，用来留白或画分割线。

```json
{ "type": "spacer", "layout": { "width": "fill", "height": 12 } }
```

```json
{
  "type": "spacer",
  "layout": { "width": "fill", "height": 0.5 },
  "style": { "background": "#E4DDD4" }
}
```

横排里的空隙把宽度写成数字。没有子节点的玻璃用 `spacer` 加 `style.glass`。示例：`templates/spacer/spacer.json`。

## list

控件是 `OTList`，继承 `RecyclerView`，单项由 `OTListAdapter` 创建。布局算到列表就停。

| 字段 | 必填 | 说明 |
| --- | --- | --- |
| `id` | 是 | `append`、`update`、`remove` 靠它找到列表 |
| `data` | 是 | `$` 表达式，求值结果是对象数组 |
| `item` | 是 | 单项模版，一个节点 |
| `direction` | 否 | `vertical` 或 `horizontal`，缺省 `vertical` |
| `gap` | 否 | 项与项之间的 dp，最后一项后面不加 |

单项里的 `$字段` 读这一项。页面上的颜色、标题要带到下一页，用事件 `params`。从列表项 `open` 时，表达式同时看这一项和所在页面，同名字段以这一项为准。

| 动作 | 必填 | 效果 |
| --- | --- | --- |
| `append` | `list` `from` `field` `data` `item` | 从 `from` 那个输入框取值，按 `item` 拼一个对象追加进去。可以再写 `empty` |
| `update` | `list` `index` `item` | 按 `index` 替换一项。`index` 是非负整数或 `$` 表达式 |
| `remove` | `list` `index` | 删掉那一项 |

`item` 里的值是字符串、字面量或 `$` 表达式。页面栈记住列表的滚动位置。单项里面的输入和勾选不会自动写回那一项。

```json
{
  "type": "list",
  "id": "day_list",
  "data": "$days",
  "direction": "vertical",
  "gap": 10,
  "layout": { "width": "fill", "height": "wrap", "grow": 1 },
  "item": {
    "type": "text",
    "text": "$title",
    "layout": { "width": "fill", "height": "wrap" },
    "style": { "fontSize": 16, "color": "#1F1A17" }
  }
}
```

`grow` 让列表吃掉列里剩下的高度，滚动发生在列表内部。外层 `column` 再写 `scroll: true` 时，两层都会接手势。示例：`templates/list/list.json`。首页、收件、城南货架、南市订单都是这个节点。

## progress

自绘的 `ProgressView`。`from` 和 `to` 是 0 到 1 的比例，可以是数字或 `$` 表达式。`animate` 缺省 `false`。`style.track` 是底色，缺省灰；`style.bar` 是进度色，缺省红。

模版不能把它写成可拖动的。控件上的 `seekable` 缺省关闭。播放页在模版画完之后，由 Demo 的 `PlayerSession` 打开拖动。

```json
{
  "type": "progress",
  "layout": { "width": "fill", "height": 7 },
  "from": 0,
  "to": "$progress",
  "animate": true,
  "style": { "track": "#E4DDD4", "bar": "#C45C26", "radius": 4 }
}
```

高度决定条的粗细。示例：`templates/progress/progress.json`。行程页和播放页里也有一条。

## lottie

协议里的 type 是 `lottie`，工厂内部叫 `Animation`。控件是 `AnimationView`，继承 `LottieAnimationView`，并实现 `Playable`。`src` 必填。

| 字段 | 缺省 | 说明 |
| --- | --- | --- |
| `src` |  | 网络用 `https://`。包内写成 `assets:animation/lottie-sunny`，不要自己加 `.json` |
| `repeat` | `"infinite"` | `"infinite"` 或非负整数 |
| `mode` | `restart` | `restart` 或 `reverse` |
| `autoPlay` | `true` | `false` 时只准备，不自动播 |

`Playable.setPlaying` 可以暂停和继续，模版里没有对应字段。播放页的 `PlayerSession` 按节点 tag 找到动画。页面栈不记当前帧。

```json
{
  "type": "lottie",
  "id": "sunny",
  "src": "assets:animation/lottie-sunny",
  "repeat": "infinite",
  "mode": "restart",
  "autoPlay": true,
  "layout": { "width": 72, "height": 72 }
}
```

给一个明确的宽高。示例：`templates/lottie/lottie.json`。

## input

控件是 `Input`，继承 `AppCompatEditText`。

| 字段 | 位置 | 说明 |
| --- | --- | --- |
| `value` | 节点 | 初始文字，可以是 `$` 表达式 |
| `hint` | 节点 | 还没输入时的占位 |
| `keyboard` | 节点 | `text` `number` `password` `email` `phone`，缺省 `text` |
| `maxLength` | 节点 | 非负整数 |
| `lines` | 节点或 `style` | 正整数，缺省一行 |
| `color` `fontSize` `align` | `style` | 和文字相同 |
| `hintColor` | `style` | 占位文字的颜色 |

有 `id` 时，每次文字变化都会把当前字符串写进页面数据的同名字段，并触发 `onChange`。`rebind` 按数据把文字设回去时，这段写回会被压住，避免再次触发 `onChange`。

`append` 的 `from` 指向输入框 `id`。页面栈弹出时，带 `id` 的输入框先写进这一页的数据，再计算 `back` 的 `params`。列表项内部的输入框不会自动写回那一项。

键盘高度由宿主处理。Demo 在 `TemplateScreen` 和 `Ime` 里吃 IME inset。

```json
{
  "type": "input",
  "id": "draft",
  "hint": "写一句",
  "keyboard": "text",
  "maxLength": 40,
  "layout": { "width": "fill", "height": 44 },
  "style": {
    "fontSize": 16,
    "color": "#1F1A17",
    "hintColor": "#8A8178",
    "background": "#FFFCF8",
    "radius": 12,
    "padding": { "start": 12, "end": 12 }
  }
}
```

示例：`templates/input/input.json`。聊天页底部和城南备忘也用它。

## checkbox

控件是 `CheckBox`，继承 `AppCompatCheckBox`。多个勾选互不影响。

`checked` 是布尔值或以 `$` 开头，缺省 `false`。`label` 是框旁边的文字。选中变化触发 `onChange`。`setChecked` 的 `target` 可以是一个 id，或 id 数组。

页面栈在 `back` 时把带 `id` 的勾选写进这一页的数据。从列表项打开的页面，结果可以写回那一项。城南看点页就是这样。

```json
{
  "type": "checkbox",
  "id": "been",
  "label": "到过",
  "checked": "$been",
  "layout": { "width": "fill", "height": "wrap" },
  "onChange": ["mark"]
}
```

示例：`templates/checkbox/checkbox.json`。

## radio

控件是 `Radio`，继承 `MaterialRadioButton`。字段和勾选框一样，另外必填 `group`。`group` 是标识符或以 `$` 开头。同一组里选中一个，其余会被清掉。不同 `group` 互不影响。组名来自表达式时，按绑定那一刻求出来的字符串分组。

`setChecked` 把 `value` 设为 `true` 时也会清掉同组的其他项。设为 `false` 只关目标。

列表里每一项要独立成组时，把 `group` 写成这一项独有的字段，例如 `"$id"`。

```json
{
  "type": "radio",
  "id": "small",
  "group": "size",
  "label": "小杯",
  "checked": true,
  "layout": { "width": "fill", "height": "wrap" }
}
```

示例：`templates/radio/radio.json`。

## switch

控件是 `Switch`，继承 `MaterialSwitch`。字段和勾选框一样，没有 `group`。多个开关不会互相关掉。

系统通知权限不是这个节点。查询或申请走 `host`，能力名是 `notifications`。开关只记录模版数据里的布尔值。

```json
{
  "type": "switch",
  "id": "notify",
  "label": "到站提醒",
  "checked": "$notify",
  "layout": { "width": "fill", "height": "wrap" },
  "onChange": ["save"]
}
```

示例：`templates/switch/switch.json`。
