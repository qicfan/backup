import { ErrorEvent, MessageEvents, ThreadWorkerGlobalScope, worker } from '@kit.ArkTS';
import { UploadItemSendable } from '../models/UploadItemSendable';
import { fileIo } from '@kit.CoreFileKit';
import { common, sendableContextManager } from '@kit.AbilityKit';
import { BusinessError, emitter, request } from '@kit.BasicServicesKit';
import { strip } from '../utils/tools';
import { WebDav } from '../utils/webdav';
import { ServerConfig } from '../models/Server';

const workerPort: ThreadWorkerGlobalScope = worker.workerPort;

/**
 * Defines the event handler to be called when the worker thread receives a message sent by the host thread.
 * The event handler is executed in the worker thread.
 *
 * @param event message data
 */
workerPort.onmessage = (event: MessageEvents) => {
  console.log(`上传线程收到消息：${JSON.stringify(event.data)}`)
  doTask(event.data).then((rs) => {
    if (rs === "SUCCESS") {
      workerPort.postMessage({action: "FINISH", code: 200, message: "", taskItemId: event.data.taskItemId});
    } else if (rs === "FILE NOT EXISTS"){
      workerPort.postMessage({action: "FILE_NOT_EXISTS", code: 404, message: "本地临时文件不存在", taskItemId: event.data.taskItemId});
    } else {
      workerPort.postMessage({action: "ERROR", code: 0, message: event.data.message, taskItemId: event.data.taskItemId});
    }
    workerPort.postMessage(rs);
  }).catch((err: BusinessError) => {
    workerPort.postMessage({action: "ERROR", code: err.code, message: err.message, taskItemId: event.data.taskItemId});
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

async function mkRemotePath(uploadItem: UploadItemSendable, webdav: WebDav): Promise<boolean> {
  const dirList: string[] = uploadItem.remoteUri.split('/').filter(part => part.length > 0);
  dirList.pop();
  let currentPath: string = strip(uploadItem.backupRootPath, '/');
  for (let dir of dirList) {
    // 创建目录
    currentPath += `/${dir}`;
    console.log(`创建远程目录: ${currentPath}`);
    const rr = await webdav.mkDir(currentPath);
    if ((rr.statusCode >= 200 && rr.statusCode < 300) || rr.statusCode == 405) {
      continue
    } else {
      // 创建目录失败
      console.error(`创建目录失败：${currentPath}`);
      return false;
    }
  }
  console.log(`创建远程目录: ${uploadItem.remoteUri}成功`)
  return true;
}

/**
 * 1。 检查文件是否存在，不存在则给主线程报错，主线程将该文件重新处理后放入队列继续
 * 2. 上传文件
 * 3. 上传文件过程中更新进度（修改数据库）
 * 4. 上传完成后删除临时文件
 * 5. 修改数据库状态
 */
function doTask(uploadItem: UploadItemSendable): Promise<string> {
  return new Promise(async (resolve, reject) => {
    // try {
    //   fileIo.statSync(uploadItem.fileUri);
    // } catch (e) {
    //   // 文件不存在
    //   if (e.code === 13900002) {
    //     return resolve("FILE NOT EXISTS")
    //   }
    //   return resolve("LOCAL FILE STAT ERROR")
    // }
    const context: common.Context = sendableContextManager.convertToContext(uploadItem.sendableContext);
    const filesDir: string = context.cacheDir;
    const fileUri = uploadItem.fileUri.replace(filesDir, 'internal://cache')
    console.log(`cacheDir: ${filesDir}, fileUri: ${uploadItem.fileUri}=>${fileUri}`);
    const serverConfig = new ServerConfig();
    serverConfig.server = uploadItem.serverBaseUrl;
    serverConfig.username = uploadItem.serverUsername;
    serverConfig.password = uploadItem.serverPassword;
    console.log(`serverConfig赋值, ${JSON.stringify(serverConfig)}`)
    try {
      let webdav = new WebDav();
      webdav.updateSerConfig(serverConfig);
      const mkRP = await mkRemotePath(uploadItem, webdav);
      if (!mkRP) {
        return resolve("CREATE REMOTE PATH FAIL")
      }
      // 检查文件是否已存在
      let existsRR: number = await webdav.exists(uploadItem.remoteUri, uploadItem.fileSize);
      if (existsRR === 2) {
        console.log(`${uploadItem.remoteUri}在服务器上存在，但是大小和本地不同，删除服务端文件。`)
        // 存在，不一致，删除远程文件
        await webdav.delete(uploadItem.remoteUri)
        existsRR = 0;
      }
      if (existsRR === 1) {
        // 已经上传完成
        console.log(`服务器上存在${uploadItem.remoteUri}，直接返回成功`)
        return resolve("SUCCESS");
      }
      console.log(`新建webdav`)
    } catch (e) {
      console.error(`新建webdav报错：${e.code}, ${e.message}`)
    }
    // 上传任务配置项
    const files: Array<request.File> = [{ filename: uploadItem.name, name: 'file', uri: fileUri, type: "" }]
    const uploadConfig: request.UploadConfig = {
      url: uploadItem.remoteUri,
      header: {'Authorization': 'Basic ' + uploadItem.auth},
      method: 'PUT', files: files, data: []
    }
    try {
      const uploadTask: request.UploadTask = await request.uploadFile(context, uploadConfig);
      uploadTask.on('complete', () => {
        uploadTask.delete().then()
        return resolve("SUCCESS")
      });
      uploadTask.on("progress", (uploadedSize: number) => {
        // 更新已上传进度
        workerPort.postMessage({action: "UPDATE_PROGRESS", code: 200, message: "", uploadedSize: uploadedSize, taskItemId: uploadItem.taskItemId})
      })
    } catch (error) {
      let err: BusinessError = error as BusinessError;
      console.error(`Invoke uploadFile failed, code is ${err.code}, message is ${err.message}`);
      reject(error)
    }
  })
}