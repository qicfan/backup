import { AppStorageV2 } from "@kit.ArkUI";
import { BreakpointConstants } from "../common/BreakpointConstants";
import { CommonConstants } from "../common/CommonConstants";
import { WinBreakpoint } from "../common/WinBreakpoint";
import { Settings } from "./Settings";
import { ConfigGlobalStatus, LoginStatus, TabItem } from "../typing";
import { WaitList } from "./WaitList";
import { SucList } from "./SucList";
import { Global } from "../models/Global";
import { ServerConfig } from "../models/Server";
import { IBestButton, IBestEmpty } from "@ibestservices/ibest-ui-v2";


@ComponentV2
export struct Home {
  @Local winBP: WinBreakpoint =
    AppStorageV2.connect(WinBreakpoint, 'windowBreakpoint', () => WinBreakpoint.getInstance())!;
  @Local global: Global = AppStorageV2.connect(Global, "global", () => Global.getInstance())!;
  @Consumer('pageInfos') pageInfos: NavPathStack = new NavPathStack();
  @Local server: ServerConfig = AppStorageV2.connect(ServerConfig, "server", () => ServerConfig.getInstance())!;
  aboutToAppear(): void {
  }

  tabItems: Array<TabItem> = [
    { icon: $r('app.media.house'), selectedIcon: $r('app.media.house_fill'), name: "待备份" },
    { icon: $r('app.media.checkmark_circle'), selectedIcon: $r('app.media.checkmark_circle_fill'), name: "云相册" },
    { icon: $r('app.media.gearshape'), selectedIcon: $r('app.media.gearshape'), name: "设置" }
  ]

  @Builder Btn() {
    IBestButton({ text: '添加服务器', type: 'primary', onBtnClick: () => {
      console.log("1")
      // 跳转到添加服务器页面
      this.pageInfos.pushPath({ name: "login" })
    } })
      .padding({top: $r("app.float.normal_padding")})
  }

  @Builder
  BottomTabBuilder(item: TabItem, index: number) {
    Column() {
      Image(index !== this.global.tabIndex ? item.icon : item.selectedIcon)
        .width($r('app.float.icon_tab_width'))
        .height($r('app.float.icon_tab_height'))
        .fillColor(index === this.global.tabIndex ? $r('app.color.tab_sel_color') : Color.Black)
      Text(item.name)
        .fontSize(this.winBP.currentWidthBreakpoint === BreakpointConstants.BREAKPOINT_LG ?
        $r('app.float.tab_lg_font_size') : $r('app.float.tab_font_size'))
        .fontWeight(CommonConstants.FONT_WEIGHT_500)
        .fontColor(index === this.global.tabIndex ? $r('app.color.tab_sel_color') : Color.Black)
        .margin({ top: $r('app.float.tab_top_margin') })
        .opacity(index === this.global.tabIndex ? CommonConstants.TEXT_OPACITY[3] : CommonConstants.TEXT_OPACITY[0])
    }
    .height(this.winBP.currentWidthBreakpoint === BreakpointConstants.BREAKPOINT_LG ? $r('app.float.tab_height_lg') :
    CommonConstants.FULL_PERCENT)
    .width(CommonConstants.FULL_PERCENT)
    .justifyContent(FlexAlign.Center)
  }

  build() {
    Tabs({
      barPosition: this.winBP.currentWidthBreakpoint === BreakpointConstants.BREAKPOINT_LG ? BarPosition.Start :
      BarPosition.End,
      index: this.global.tabIndex
    }) {
      TabContent() {
        if (this.global.loginStatus == LoginStatus.LOGIN && this.global.configGlobalStatus == ConfigGlobalStatus.YES) {
          WaitList()
        } else {
          // 显示去登录的按钮
          IBestEmpty({
            description: '添加服务器后才可以开始收集要备份的照片（因为要检查服务器中是否已存在相同的照片）',
            defaultBuilder: (): void => this.Btn()
          })
        }
      }
      .tabBar(this.BottomTabBuilder(this.tabItems[0], 0))

      TabContent() {
        SucList();
      }
      .tabBar(this.BottomTabBuilder(this.tabItems[1], 1))

      TabContent() {
        Settings();
      }
      .tabBar(this.BottomTabBuilder(this.tabItems[2], 2))
    }
    .barWidth(this.winBP.currentWidthBreakpoint === BreakpointConstants.BREAKPOINT_LG ?
    $r('app.float.bottom_tab_bar_width_lg') :
    CommonConstants.FULL_PERCENT)
    // .barHeight(this.winBP.currentWidthBreakpoint === BreakpointConstants.BREAKPOINT_LG ? CommonConstants.FULL_PERCENT :
    //   (deviceInfo.deviceType === CommonConstants.DEVICE_TYPES[0] ? $r('app.float.tab_size_lg') :
    //   $r('app.float.tab_size')))
    .barMode(BarMode.Fixed)
    .vertical(this.winBP.currentWidthBreakpoint === BreakpointConstants.BREAKPOINT_LG)
    .barBackgroundColor($r("app.color.tab_background_color"))
    .barOverlap(false)
    .scrollable(false)
    .animationDuration(300)
    .height(CommonConstants.FULL_PERCENT)
    .width(CommonConstants.FULL_PERCENT)
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
    .onChange((index: number) => {
      this.global.tabIndex = index;
    })
  }
}