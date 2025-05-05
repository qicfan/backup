import { IBestEmpty, IBestNotify, IBestPullRefresh } from "@ibestservices/ibest-ui-v2";
import { Task } from "../models/Task";
import { TaskItem } from "./TaskItem";
import { BusinessError, emitter } from "@kit.BasicServicesKit";
import { Global } from "../models/Global";

@ComponentV2
export struct TaskList {
  @Consumer('pageInfos') pageInfos: NavPathStack = new NavPathStack()

  @Local list: Task[] = [];
  @Local c: number = 0;
  @Local t: number = 0;

  aboutToAppear(): void {
    // 查询任务列表
    this.getList('pull');
    emitter.on(Global.COLLECT_PHOTO_FINISH_EVENT, (data) => {
      // 重新载入列表
      if (data.data?.exists) {
        this.getList('pull');
      }
    });
  }

  aboutToDisappear(): void {
    emitter.off(Global.COLLECT_PHOTO_FINISH_EVENT);
  }

  // 查询所有未完成的 + 一个已完成的 + 所有其他已完成的统计
  async getList(direction: string) {
    try {
      let lastIds: Array<number> = [];
      const task = await Task.lastFinishTask();
      const waitList = await Task.getWaitList();
      if (task === null) {
        this.list = waitList;
      } else {
        this.list = [...waitList, task]
      }
      this.list.forEach((item) => lastIds.push(item.id));
      lastIds = Array.from(new Set(lastIds)); // 去除重复项
      console.log(`lastId: ${JSON.stringify(lastIds)}`)
      const rs: Array<number> = await Task.finishStat(lastIds);
      this.c = rs[0];
      this.t = rs[1];
    } catch (error) {
      let err = error as BusinessError
      console.log(`查询照片失败，code=${err.code}, msg=${err.message}`)
      IBestNotify.show({
        message: `加载任务列表失败，错误码：${err.code}，错误内容：${err.message}`,
        duration: 3000
      })
    }

  }

  build() {
    if (this.list.length === 0) {
      Column() {
        IBestEmpty({
          description: "还没有备份记录"
        })
      }
      .padding($r('app.float.normal_padding'))
      .width('100%')
      .height('100%')
      .backgroundColor($r('app.color.ibest_background'))
    } else {
      Column() {
        List() {
          ForEach(this.list, (item: Task) => {
            TaskItem({task: item})
          }, (item: Task) => item.id + '')
        }
        .width('100%')
        .layoutWeight(1)
        .backgroundColor($r('app.color.ibest_background'))
        if (this.c > 0 && this.t > 0) {
          Column() {
            Text(`除上面列表外，已备份${this.t}个照片或视频`)
          }
          .justifyContent(FlexAlign.Center)
          .width('100%')
          .height(40)
        }
      }
      .width('100%')
      .height('100%')
    }
  }
}