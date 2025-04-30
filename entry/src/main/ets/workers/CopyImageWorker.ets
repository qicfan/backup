import { ErrorEvent, MessageEvents, ThreadWorkerGlobalScope, worker } from '@kit.ArkTS';
import { CopyItemSendable } from '../models/CopyItemSendable';
import { copyImg2Sandbox } from '../utils/tools';

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
    copyFile(event.data).then(() => {
        workerPort.postMessage(copyItem.taskItemId);
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
    return copyImg2Sandbox(copyItem.imageUri, copyItem.fileUri, copyItem.fileSize);
}