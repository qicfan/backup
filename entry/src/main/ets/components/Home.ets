import { AppStorageV2 } from "@kit.ArkUI";
import { BreakpointConstants } from "../common/BreakpointConstants";
import { CommonConstants } from "../common/CommonConstants";
import { WinBreakpoint } from "../common/WinBreakpoint";
import { Settings } from "./Settings";
import { deviceInfo } from "@kit.BasicServicesKit";
import { TabItem } from "../typing";


@ComponentV2
export struct Home {
  @Local winBP: WinBreakpoint = AppStorageV2.connect(WinBreakpoint, 'windowBreakpoint', () => WinBreakpoint.getInstance())!;
  // @Provider("currentBottomIndex") currentBottomIndex: number = 0;

  aboutToAppear(): void {
  }
  tabItems: Array<TabItem>  = [
    {icon: $r('app.media.house'), selectedIcon: $r('app.media.house_fill'), name: "待备份"},
    {icon: $r('app.media.checkmark_circle'), selectedIcon: $r('app.media.checkmark_circle_fill'), name: "已备份"},
    {icon: $r('app.media.gearshape'), selectedIcon: $r('app.media.gearshape'), name: "设置"}
  ]

  @Builder
  BottomTabBuilder(item: TabItem, index: number) {
    Column() {
      Image(index !== this.winBP.index ? item.icon : item.selectedIcon)
        .width($r('app.float.icon_tab_width'))
        .height($r('app.float.icon_tab_height'))
      Text(item.name)
        .fontSize(this.winBP.currentWidthBreakpoint === BreakpointConstants.BREAKPOINT_LG ?
        $r('app.float.tab_lg_font_size') : $r('app.float.tab_font_size'))
        .fontWeight(CommonConstants.FONT_WEIGHT_500)
        .fontColor(index === this.winBP.index ? $r('app.color.tab_sel_color') : Color.Black)
        .margin({ top: $r('app.float.tab_top_margin') })
        .opacity(index === this.winBP.index ? CommonConstants.TEXT_OPACITY[3] : CommonConstants.TEXT_OPACITY[0])
    }
    .height(this.winBP.currentWidthBreakpoint === BreakpointConstants.BREAKPOINT_LG ? $r('app.float.tab_height_lg') :
    CommonConstants.FULL_PERCENT)
    .width(CommonConstants.FULL_PERCENT)
    .justifyContent(FlexAlign.Center)
  }

  build() {
    Tabs({
      barPosition: this.winBP.currentWidthBreakpoint === BreakpointConstants.BREAKPOINT_LG ? BarPosition.Start :
      BarPosition.End
    }) {
      TabContent() {
        Text('a')
          .height('100%')
          .width('100%')
          .backgroundColor($r('app.color.ibest_white'))
      }
      .tabBar(this.BottomTabBuilder(this.tabItems[0], 0))

      TabContent() {
        Text('a')
        .height('100%')
        .width('100%')
          .backgroundColor($r('app.color.ibest_white'))
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
      this.winBP.index = index;
    })
  }
}