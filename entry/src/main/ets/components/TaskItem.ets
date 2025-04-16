import { IBestLoading, IBestProgress } from "@ibestservices/ibest-ui-v2"
import { Task } from "../models/Task"
import { TaskStatus, TaskType } from "../typing";
import { dateTimeFromTimestamp } from "../utils/date";
import { Cell } from "./Cell"
import { emitter } from "@kit.BasicServicesKit";
import { Global } from "../models/Global";

@ComponentV2
export struct TaskItem {
  @Param task: Task = new Task();
  @Local doing: boolean = false;

  @Computed
  get process() {
    return Math.floor(this.task.uploadedSize / this.task.size * 100)
  }

  @Computed
  get statusName() {
    switch(this.task.status) {
      case TaskStatus.WAIT:
        return '等待备份';
      case TaskStatus.PROCESS:
        return '备份中...';
      case TaskStatus.FINISH:
        return '备份完成';
    }
  }

  aboutToAppear(): void {
    emitter.on(Global.START_TASK_EVENT, (data) => {
      const id: undefined | number = data?.data?.id;
      if (id && id === this.task.id) {
        this.doing = true;
        this.task.fetch().then(() => {
          console.log("开始更新任务" + data?.data?.id + `的UI状态, status=${this.task.status}, 已上传字节: ${this.task.uploadedSize}， 总字节：${this.task.size}, 进度: ${this.process}`)
          if (this.task.status === TaskStatus.FINISH) {
            this.doing = false;
          }
        })
      }
    })
  }

  build() {
    Column() {
      Column() {
        Flex({
          direction: FlexDirection.Row,
          wrap: FlexWrap.NoWrap,
          justifyContent: FlexAlign.SpaceBetween,
          alignItems: ItemAlign.Center
        }) {
          Column() {
            Flex({
              direction: FlexDirection.Row,
              wrap: FlexWrap.NoWrap,
              justifyContent: FlexAlign.SpaceBetween,
              alignItems: ItemAlign.Center
            }) {
              Text(this.statusName)
                .textAlign(TextAlign.Start)
              Text(dateTimeFromTimestamp(this.task.createdAt))
                .textAlign(TextAlign.End)
            }
            .width('100%')

            Text(`总计${this.task.total}张，成功${this.task.success}，失败${this.task.failed}`)
              .width('100%')
              .textAlign(TextAlign.Start)
              .fontSize($r("sys.float.ohos_id_popup_text_font_size"))
              .fontColor($r("app.color.ibest_field_prefix_font_color"))
            if (this.task.status !== TaskStatus.FINISH) {
              Column() {
                IBestProgress({
                  value: this.process
                })
              }
              .padding({ left: $r("app.float.normal_padding") })
            }
          }
          .layoutWeight(1)

          if (this.doing) {
            Column() {
              IBestLoading()
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
      .margin({ bottom: $r("app.float.normal_padding") })
      .backgroundColor($r('app.color.ibest_background'))
      .width('100%')
      .padding($r("app.float.normal_padding"))
    }
  }
}