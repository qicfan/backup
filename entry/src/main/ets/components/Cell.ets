import { IBestIcon } from "@ibestservices/ibest-ui-v2"

@ComponentV2
export struct Cell {
  @Builder buildRight () {}

  @Param title: string = ""
  @Param left: string = ""
  @Param right: string = ""
  @BuilderParam rightBuilder: () => void = this.buildRight
  @Param content: string = ""
  @Param showArrow: boolean = false


  build() {
    Column() {
      if (this.title !== "") {
        Text(this.title)
          .width('100%')
          .fontSize($r("sys.float.ohos_id_popup_text_font_size"))
          .textAlign(TextAlign.Start)
          .width('100%')
          .padding({
            left: $r('app.float.normal_padding'),
            right: $r('app.float.normal_padding'),
          })
      }
      Flex({
        direction: FlexDirection.Row,
        wrap: FlexWrap.NoWrap,
        justifyContent: FlexAlign.SpaceBetween,
        alignItems: ItemAlign.Center
      }) {
        Column() {
          if (this.left !== "" || this.right !== "") {
            Flex({
              direction: FlexDirection.Row,
              wrap: FlexWrap.NoWrap,
              justifyContent: FlexAlign.SpaceBetween,
              alignItems: ItemAlign.Center
            }) {
              Text(this.left)
                .textAlign(TextAlign.Start)
                // .fontColor($r("app.color.ibest_table_header_text_color"))
              if (this.right !== "") {
                Text(this.right)
                  .textAlign(TextAlign.End)
                  // .fontColor($r("app.color.ibest_table_header_text_color"))
              }
              if (this.rightBuilder !== undefined) {
                this.rightBuilder()
              }
            }
            .width('100%')
          }

          if (this.content !== "") {
            Text(this.content)
              .width('100%')
              .textAlign(TextAlign.Start)
              .fontSize($r("sys.float.ohos_id_popup_text_font_size"))
              .fontColor($r("app.color.ibest_field_prefix_font_color"))
          }
        }
        .layoutWeight(1)

        if (this.showArrow) {
          Column() {
            IBestIcon({ name: 'arrow' })
          }
          .width(24)
          .alignItems(HorizontalAlign.Center)
          .justifyContent(FlexAlign.Center)
        }
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
    .margin({bottom: $r('app.float.normal_padding'), left: $r('app.float.normal_padding'), right:$r('app.float.normal_padding')})
    .backgroundColor($r("app.color.ibest_background"))
  }
}