import { bundleManager } from "@kit.AbilityKit"

@ComponentV2
export struct About {
  @Local version: string = ""
  @Local bundleName: string = ""

  aboutToAppear(): void {
    bundleManager.getBundleInfoForSelf(bundleManager.BundleFlag.GET_BUNDLE_INFO_DEFAULT).then((bundle) => {
      this.version = bundle.versionName
      this.bundleName = bundle.name;
    })
  }
  build() {
    Column() {
      Text("关于")
        .width('100%')
        .fontSize($r("sys.float.ohos_id_popup_text_font_size"))
        .textAlign(TextAlign.Start)
        .width('100%')
        .padding({
          left: $r('app.float.normal_padding'),
          right: $r('app.float.normal_padding'),
        })
      Column() {
        Text("开源仓库: https://github.com/qicfan/backup")
          .width('100%')
          .textAlign(TextAlign.Start)
          .fontSize($r("sys.float.ohos_id_popup_text_font_size"))
          .fontColor($r("app.color.ibest_field_prefix_font_color"))
        Text("联系邮箱: qicfan@qq.com")
          .width('100%')
          .textAlign(TextAlign.Start)
          .fontSize($r("sys.float.ohos_id_popup_text_font_size"))
          .fontColor($r("app.color.ibest_field_prefix_font_color"))
        Text("当前版本: " + this.version)
          .width('100%')
          .textAlign(TextAlign.Start)
          .fontSize($r("sys.float.ohos_id_popup_text_font_size"))
          .fontColor($r("app.color.ibest_field_prefix_font_color"))
      }
      .padding($r('app.float.normal_padding'))
      .backgroundColor($r("app.color.ibest_search_inner_background"))
      .borderRadius(10)
      .shadow({
        radius: 8,
        color: Color.Gray,
        offsetX: 10,
        offsetY: 10
      })
    }
    .margin({
      bottom: $r('app.float.normal_padding'),
      left: $r('app.float.normal_padding'),
      right: $r('app.float.normal_padding')
    })
    .backgroundColor($r("app.color.ibest_background"))
  }
}