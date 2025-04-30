import { IBestEmpty, IBestNotify, IBestPullRefresh } from "@ibestservices/ibest-ui-v2";
import { Task } from "../models/Task";
import { TaskItem } from "./TaskItem";
import { BusinessError, emitter } from "@kit.BasicServicesKit";
import { Global } from "../models/Global";

@ComponentV2
export struct TaskList {
  @Consumer('pageInfos') pageInfos: NavPathStack = new NavPathStack()

  @Local list: Task[] = [];

  private page: number = 1;
  private pageSize: number = 20;

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

  async getList(direction: string) {
    if (direction == 'pull') {
      this.page = 1;
    } else {
      this.page ++;
    }
    try {
      const list = await Task.getList(this.page, this.pageSize);
      // console.log(`tasklist组件查询到 ${list.length}条数据`)
      if (this.page === 1) {
        this.list = list
      } else {
        this.list = this.list.concat(list)
      }

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
      List() {
        ForEach(this.list, (item: Task) => {
          TaskItem({task: item})
        }, (item: Task) => item.id + '')
      }
      .width('100%')
      .height('100%')
      .backgroundColor($r('app.color.ibest_background'))
    }
  }
}