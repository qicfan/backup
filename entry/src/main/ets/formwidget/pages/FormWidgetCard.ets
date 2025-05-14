enum FormStatus {DEFAULT=0, COLLECT=1, EXEC=2};

@Entry
@Component
struct FormWidgetCard {

  @LocalStorageProp('formId') formId: string = '';
  @LocalStorageProp('status') status: FormStatus = FormStatus.DEFAULT;
  @LocalStorageProp('preTotal') preTotal: number = 0; // 待备份总数
  @LocalStorageProp('total') total: number = 0; // 剩余备份数

  /*
   * The title.
   */
  readonly startTitle: string = '开始备份';
  readonly stopTitle: string = '停止备份';
  readonly collectTitle: string = '查找未备份项...';
  readonly execTitle: string = '备份中...'
  /*
   * The action type.
   */
  readonly actionType: string = 'call';
  /*
   * The ability name.
   */
  readonly abilityName: string = 'EntryAbility';
  /*
   * The width percentage setting.
   */
  readonly fullWidthPercent: string = '100%';
  /*
   * The height percentage setting.
   */
  readonly fullHeightPercent: string = '100%';

  aboutToAppear(): void {
    console.log(this.formId);
  }

  build() {
    Column() {
      if (this.status === FormStatus.DEFAULT) {
        Row() {
          Image($r("sys.media.ohos_ic_public_play"))
            .height(24)
            .width(24)
            .margin({ right: $r('app.float.inner_padding') })
          Text(this.startTitle)
            .fontSize($r('app.float.font_size'))
            .fontWeight(FontWeight.Medium)
            .fontColor($r('sys.color.font_primary'))
        }
        .height(this.fullHeightPercent)
        .width(this.fullWidthPercent)
        .justifyContent(FlexAlign.Center)
        .alignItems(VerticalAlign.Center)
        .onClick(() => {
          postCardAction(this, {
            action: this.actionType,
            abilityName: this.abilityName,
            params: {
              formId: this.formId,
              // 需要调用的方法名称
              method: 'backup'
            }
          });
        })
      }
      if (this.status === FormStatus.COLLECT) {
        Column() {
          Text(this.collectTitle)
            .fontSize($r('app.float.sm_font_size'))
            .fontWeight(FontWeight.Medium)
            .fontColor($r('sys.color.font_primary'))
        }
        .height(this.fullHeightPercent)
        .width(this.fullWidthPercent)
        .alignItems(HorizontalAlign.Center)
        .justifyContent(FlexAlign.Center)
      }
    }
  }
}