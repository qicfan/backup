import { ErrorEvent, MessageEvents, ThreadWorkerGlobalScope, worker } from '@kit.ArkTS';
import { CopyItemSendable } from '../models/CopyItemSendable';
import { copyImg2Sandbox, fileSize } from '../utils/tools';
import { photoAccessHelper } from '@kit.MediaLibraryKit';
import { Photos } from '../utils/photos';
import { common, sendableContextManager } from '@kit.AbilityKit';
import { CopyWorkerMessage } from '../typing';

const workerPort: ThreadWorkerGlobalScope = worker.workerPort;

/**
 * Defines the event handler to be called when the worker thread receives a message sent by the host thread.
 * The event handler is executed in the worker thread.
 *
 * @param event message data
 */
workerPort.onmessage = (event: MessageEvents) => {
  const copyItem: CopyItemSendable = event.data;
  // console.log(`复制线程收到消息：${JSON.stringify(copyItem)}`)
  copyFile(event.data).then((msg) => {
    workerPort.postMessage(msg);
  })
};

/**
 * Defines the event handler to be called when the worker receives a message that cannot be deserialized.
 * The event handler is executed in the worker thread.
 *
 * @param event message data
 */
workerPort.onmessageerror = (event: MessageEvents) => {
};

/**
 * Defines the event handler to be called when an exception occurs during worker execution.
 * The event handler is executed in the worker thread.
 *
 * @param event error message
 */
workerPort.onerror = (event: ErrorEvent) => {
};

async function copyFile(copyItem: CopyItemSendable) {
  const context: common.Context = sendableContextManager.convertToContext(copyItem.sendableContext);
  if (copyItem.subType === photoAccessHelper.PhotoSubtype.MOVING_PHOTO) {
    // 动态图，请求封面图片+视频
    const rs = await Photos.saveMovingPhoto(context, copyItem.imageUri, copyItem.fileUri, copyItem.videoUri);
    if (rs !== "success") {
      return false;
    }
    // 更新taskItem的文件大小
    const workMsg: CopyWorkerMessage = {
      action: "FINISH",
      code: 200,
      message: "",
      taskItemId: copyItem.taskItemId,
      imageSize: fileSize(copyItem.imageUri),
      videoSize: fileSize(copyItem.videoUri)
    }
    return workMsg;
  }
  // 普通图片和视频
  copyImg2Sandbox(copyItem.imageUri, copyItem.fileUri, copyItem.fileSize);
  const workMsg: CopyWorkerMessage = {
    action: "FINISH",
    code: 200,
    message: "",
    taskItemId: copyItem.taskItemId,
    imageSize: copyItem.fileSize,
    videoSize: 0
  }
  return workMsg;
}