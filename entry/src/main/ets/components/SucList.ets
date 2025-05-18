import { CommonConstants } from "../common/CommonConstants";
import { TaskItem } from "../models/TaskItem"
import { TaskItemComponent } from "./TaskItemComponent";
import { IBestEmpty } from "@ibestservices/ibest-ui-v2";
import { SucTaskItemDataSource } from "../models/TaskItemDataSource";
import { WinBreakpoint } from "../common/WinBreakpoint";
import { AppStorageV2 } from "@kit.ArkUI";
import { Global } from "../models/Global";

@ComponentV2
export struct SucList {
  @Local isRefreshing: boolean = false;
  @Local isLoading: boolean = false;
  @Local total: number = 0;
  @Local winBP: WinBreakpoint =
    AppStorageV2.connect(WinBreakpoint, 'windowBreakpoint', () => WinBreakpoint.getInstance())!;
  @Local global: Global = AppStorageV2.connect(Global, "global", () => Global.getInstance())!;
  @Provider("taskItemDataSource") data: SucTaskItemDataSource = new SucTaskItemDataSource();

  private scroller: Scroller = new Scroller();
  page: number = 1;
  pageSize: number = 50;
  aboutToAppear(): void {
    this.getList(1).then(() => {})
  }

  async getList(page: number = 1) {
    if (page === 1) {
      this.total = this.data.totalCount();
    }
    this.page = page;
    // 查询未备份照片列表
    const items = await TaskItem.getSuccessList(page, this.pageSize)
    if (this.page === 1) {
      this.data.clearData();
    }
    this.data.addData(items);
    if (this.page === 1) {
      this.data.notifyDataReload();
    }
  }

  get hasMore(): boolean {
    if (this.data.currentCount() >= this.data.totalCount()) return false;
    return true;
  }

  onRefresh(direction: string) {
    if (this.global.processId > 0) {
      this.isRefreshing = false;
      return ;
    }
    if (direction === 'pull') {
      this.getList(1).then(() => {
        this.isRefreshing = false;
      })
    } else {
      // 上滑加载更多
      this.getList(this.page + 1).then(() => {
        this.isRefreshing = false;
      })
    }
  }

  build() {
    Column() {
      Refresh({ refreshing: $$this.isRefreshing, promptText: "下拉刷新待备份列表"}) {
        if (this.total > 0) {
          Grid(this.scroller) {
            LazyForEach(this.data, (item: TaskItem, index: number) => {
              GridItem() {
                TaskItemComponent({ taskItem: item, index: index })
              }
            }, (item: TaskItem) => item ? item.id + '' : "0")
          }
          .margin($r('app.float.normal_padding'))
          .cachedCount(10)
          .rowsGap(3)
          .columnsGap(3)
          .columnsTemplate(`repeat(auto-fit, ${this.winBP.imageSize})`)
          .nestedScroll({
            scrollForward: NestedScrollMode.PARENT_FIRST,
            scrollBackward: NestedScrollMode.SELF_FIRST,
          })
          .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
          .scrollBar(BarState.Auto)
          .onScrollIndex((start: number, end: number) => {
            if (!this.hasMore) return ;
            if (end < this.data.currentCount() - 1) return;
            this.isLoading = true;
            this.getList(this.page + 1).then(() => {
              this.isLoading = false;
            })
          })
        } else {
          IBestEmpty({
            description: "还没有已备份的照片或视频"
          })
        }
      }
      .width('100%')
      .height('100%')
      .onRefreshing(() => {
        this.onRefresh('pull')
      })
    }
    .width(CommonConstants.FULL_PERCENT)
    .height(CommonConstants.FULL_PERCENT)
    .justifyContent(FlexAlign.Start)
  }
}