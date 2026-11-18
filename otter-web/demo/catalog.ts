export type Entry = {
  page: string
  title: string
  desc: string
  tag: string
  template?: string
  data?: string
}

export type Section = { title: string; entries: Entry[] }

const component = (page: string, title: string, desc: string): Entry => ({
  page,
  title,
  desc,
  tag: "组件",
  template: `templates/${page}/${page}.json`,
  data: `templates/${page}/mock-data/${page}.json`,
})

export const sections: Section[] = [
  {
    title: "场景",
    entries: [
      { page: "market", title: "南市", desc: "街区店铺、购物车和订单", tag: "店铺" },
      {
        page: "permission",
        title: "权限",
        desc: "查看、申请、到设置里打开。相机、麦克风、位置、相册和通知",
        tag: "能力",
      },
      { page: "stack", title: "城南", desc: "四站、看点和备忘。勾选和句子会回到上一页", tag: "栈" },
      {
        page: "weather",
        title: "天气",
        desc: "渐变卡片、小时预报和一周趋势",
        tag: "场景",
        template: "templates/weather-card-demo/weather-card.json",
        data: "templates/weather-card-demo/mock-data/weather-card.json",
      },
      {
        page: "journey",
        title: "行程",
        desc: "头图、进度和可滚动的日程",
        tag: "场景",
        template: "templates/journey/journey.json",
        data: "templates/journey/mock-data/journey.json",
      },
      {
        page: "inbox",
        title: "收件",
        desc: "一长串会话，点开看是谁",
        tag: "场景",
        template: "templates/inbox/inbox.json",
        data: "templates/inbox/mock-data/inbox.json",
      },
      {
        page: "player",
        title: "播放",
        desc: "封面、进度和控制",
        tag: "场景",
        template: "templates/player/player.json",
        data: "templates/player/mock-data/player.json",
      },
      {
        page: "chat",
        title: "聊天",
        desc: "左右气泡和底部输入",
        tag: "场景",
        template: "templates/chat/chat.json",
        data: "templates/chat/mock-data/chat.json",
      },
      {
        page: "glass",
        title: "液态玻璃",
        desc: "拖动背景，看磨砂、染色和按住变亮",
        tag: "场景",
        template: "templates/glass/glass.json",
        data: "templates/glass/mock-data/glass.json",
      },
    ],
  },
  {
    title: "组件",
    entries: [
      component("column", "Column", "纵向容器的全部属性"),
      component("row", "Row", "横向容器的全部属性"),
      component("text", "Text", "文案、颜色、字号和对齐"),
      component("image", "Image", "本地图和网络图"),
      component("spacer", "Spacer", "留白、分割线和圆角"),
      component("list", "List", "纵向和横向都能滚很长"),
      component("progress", "Progress", "区间、颜色和动画"),
      component("lottie", "Lottie", "资源、重复和播放方式"),
      component("input", "Input", "文案、占位、键盘和字数"),
      component("checkbox", "CheckBox", "选中、颜色、全选和全不选"),
      component("radio", "Radio", "同组互斥、标签和颜色"),
      component("switch", "Switch", "开关、标签和颜色"),
    ],
  },
  {
    title: "调试",
    entries: [
      {
        page: "bundle",
        title: "生成",
        desc: "输入 query，向后端要一个签名包并渲染",
        tag: "服务",
      },
    ],
  },
]

export function findEntry(page: string): Entry | undefined {
  return sections.flatMap((section) => section.entries).find((entry) => entry.page === page)
}
