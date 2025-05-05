import { IBestIcon, IBestLoading, IBestProgress } from "@ibestservices/ibest-ui-v2"
import { Task } from "../models/Task"
import { TaskStatus } from "../typing";
import { dateTimeFromTimestamp } from "../utils/date";
import { emitter } from "@kit.BasicServicesKit";
import { Global } from "../models/Global";
import { AppStorageV2 } from "@kit.ArkUI";

@ComponentV2
export struct TaskItem {
  @Consumer('pageInfos') pageInfos: NavPathStack = new NavPathStack()
  @Local global: Global = AppStorageV2.connect(Global, "global", () => Global.getInstance())!;

  @Param task: Task = new Task();
  @Local doing: boolean = false;

  private siHandle: number = 0;

  @Computed
  get process() {
    return parseFloat(((this.task.success + this.task.failed) / this.task.total * 100).toFixed(2))
  }

  @Computed
  get statusName() {
    switch (this.task.status) {
      case TaskStatus.WAIT:
        return '等待备份';
      case TaskStatus.PROCESS:
        return '备份中...';
      case TaskStatus.FINISH:
        return '备份完成';
    }
  }

  aboutToAppear(): void {
    emitter.on(Global.UPDATE_TASK_EVENT, (data) => {
      this.updateTask(data?.data?.id);
    })
  }

  aboutToDisappear(): void {
    emitter.off(Global.UPDATE_TASK_EVENT);
  }

  updateTask(id: number) {
    if (id && id === this.task.id) {
      this.task.fetch().then(() => {
        if (this.task.status === TaskStatus.PROCESS) {
          this.doing = true;
        } else {
          this.doing = false;
        }
      })
    }
  }

  startTask() {
    if (this.global.processId == this.task.id) {
      // 已经启动了
      return ;
    }
    this.siHandle = setInterval(() => {
      // 每隔1秒检查进度
      this.task.fetch().then(() => {
        console.log(`检查任务${this.task.id}进度，状态: ${this.task.status},成功：${this.task.success}, 失败:${this.task.failed}, 已上传字节数：${this.task.realUploadedSize}，总字节数：${this.task.size}`)
        if (this.task.status === TaskStatus.FINISH || this.task.status === TaskStatus.WAIT) {
          clearInterval(this.siHandle);
          this.siHandle = 0;
          return ;
        }
      })
    }, 1000)
    console.log("发送开始任务通知：" + this.task.id)
    emitter.emit(Global.START_WAIT_TASK_EVENT, { data: { id: this.task.id } });
  }

  stopTask() {
    console.log("发送暂停任务通知：" + this.task.id)
    this.doing = false;
    emitter.emit(Global.STOP_TASK_EVENT, { data: { id: this.task.id } });
    this.siHandle = setInterval(() => {
      // 每隔1秒检查进度
      this.task.fetch().then(() => {
        console.log(`检查任务${this.task.id}进度，状态: ${this.task.status},成功：${this.task.success}, 失败:${this.task.failed}, 已上传字节数：${this.task.realUploadedSize}，总字节数：${this.task.size}`)
        if (this.task.status === TaskStatus.FINISH || this.task.status === TaskStatus.WAIT) {
          clearInterval(this.siHandle);
          this.siHandle = 0;
          return ;
        }
      })
    }, 1000)
  }

  build() {
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
            if (this.doing) {
              IBestLoading({ loadingSize: 18 })
            }
            Text(this.statusName)
              .textAlign(TextAlign.Start)
            Text(dateTimeFromTimestamp(this.task.createdAt))
              .textAlign(TextAlign.End)
          }
          .width('100%')

          Text(`总计${this.task.total}张，成功${this.task.success}，失败${this.task.failed}，上传中${this.task.uploadCount}`)
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
            .width('100%')
            .padding({ left: $r("app.float.normal_padding") })
          }
          if (this.task.cancelReason !== "" && this.task.status === TaskStatus.WAIT) {
            Column() {
              Text('上次停止原因：' + this.task.cancelReason)
                .fontSize($r("sys.float.ohos_id_popup_text_font_size"))
                .textAlign(TextAlign.Start)
            }
            .alignItems(HorizontalAlign.Start)
            .width('100%')
          }
        }
        .layoutWeight(1)
        .onClick(() => {
          this.pageInfos.pushPath({name: "TaskFiles", param: this.task.id})
        })

        Column() {
          if (this.task.status == TaskStatus.WAIT) {
            IBestIcon({ name: "play-circle-o", iconSize: 24, color: Color.Blue })
          }
          if (this.task.status == TaskStatus.PROCESS) {
            IBestIcon({ name: "pause-circle-o", iconSize: 24 })
          }
          if (this.task.status == TaskStatus.FINISH && this.task.failed === 0) {
            IBestIcon({ name: "passed", iconSize: 24, color: Color.Green })
          }
          if (this.task.status == TaskStatus.FINISH && this.task.failed > 0) {
            IBestIcon({ name: "upgrade", iconSize: 24, color: Color.Red })
          }
        }
        .width(24)
        .alignItems(HorizontalAlign.Center)
        .justifyContent(FlexAlign.Center)
        .margin({ left: $r('app.float.inner_padding') })
        .onClick(() => {
          if (this.task.status == TaskStatus.WAIT || (this.task.status == TaskStatus.FINISH && this.task.failed > 0)) {
            this.startTask();
          }
          if (this.task.status == TaskStatus.PROCESS) {
            this.stopTask();
          }
        })
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