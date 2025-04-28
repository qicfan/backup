import { IBestEmpty } from "@ibestservices/ibest-ui-v2";
import { Global } from "../models/Global";
import { Task } from "../models/Task";
import { TaskItem } from "../models/TaskItem";
import { TaskFileItem } from "./TaskFileItem";
import { AppStorageV2 } from "@kit.ArkUI";
import { emitter } from "@kit.BasicServicesKit";

@ComponentV2
export struct TaskFiles {
  @Consumer('pageInfos') pageInfos: NavPathStack = new NavPathStack()
  @Local global: Global = AppStorageV2.connect(Global, "global", () => Global.getInstance())!;
  @Local task: Task = new Task();
  @Local list: TaskItem[] = [];
  @Local processItem: TaskItem | undefined = undefined;

  private taskId: number = 0;

  aboutToAppear(): void {
    this.task.id = this.pageInfos.getParamByIndex(0) as number;
    this.task.fetch().then(() => {
      this.getData().then();
      this.intervalUpdate();
    })

  }

  intervalUpdate() {
    emitter.on(Global.UPDATE_TASK_EVENT, () => {
      this.getData();
    })
  }

  async getData() {
    // 读取失败列表
    this.list = await this.task.getFailItems(1, 9999999);
  }

  build() {
    NavDestination() {
      if (this.list.length === 0) {
        Column() {
          IBestEmpty({
            description: "没有上传失败的文件"
          })
        }
        .padding($r('app.float.normal_padding'))
        .width('100%')
        .layoutWeight(1)
        .backgroundColor($r('app.color.ibest_background'))
      } else {
        List() {
          ForEach(this.list, (item: TaskItem) => {
            TaskFileItem({fileItem: item})
              .onClick(() => {
                this.pageInfos.pushPath({ name: "TaskFiles", param: item.id })
              })
          }, (item: Task) => item.id + '')
        }
        .width('100%')
        .height('100%')
      }
    }
    .title('上传失败列表')
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.ibest_background'))
  }
}