// Dialog.ets
import { BusinessError } from '@kit.BasicServicesKit';
import { ComponentContent, promptAction, UIContext } from '@kit.ArkUI';

export class Dialog {
  static ctx: UIContext;
  static contentNode: ComponentContent<Object>;
  static options: promptAction.BaseDialogOptions;

  static setContext(context: UIContext) {
    Dialog.ctx = context;
  }

  static setContentNode(node: ComponentContent<Object>) {
    Dialog.contentNode = node;
  }

  static setOptions(options: promptAction.BaseDialogOptions) {
    Dialog.options = options;
  }

  static openDialog() {
    if (Dialog.contentNode !== null) {
      Dialog.ctx.getPromptAction().openCustomDialog(Dialog.contentNode, Dialog.options)
        .then(() => {
          console.info('OpenCustomDialog complete.')
        })
        .catch((error: BusinessError) => {
          let message = (error as BusinessError).message;
          let code = (error as BusinessError).code;
          console.error(`OpenCustomDialog args error code is ${code}, message is ${message}`);
        })
    }
  }

  static closeDialog() {
    if (Dialog.contentNode !== null) {
      Dialog.ctx.getPromptAction().closeCustomDialog(Dialog.contentNode)
        .then(() => {
          console.info('CloseCustomDialog complete.')
        })
        .catch((error: BusinessError) => {
          let message = (error as BusinessError).message;
          let code = (error as BusinessError).code;
          console.error(`CloseCustomDialog args error code is ${code}, message is ${message}`);
        })
    }
  }

  static updateDialog(options: promptAction.BaseDialogOptions) {
    if (Dialog.contentNode !== null) {
      Dialog.ctx.getPromptAction().updateCustomDialog(Dialog.contentNode, options)
        .then(() => {
          console.info('UpdateCustomDialog complete.')
        })
        .catch((error: BusinessError) => {
          let message = (error as BusinessError).message;
          let code = (error as BusinessError).code;
          console.error(`UpdateCustomDialog args error code is ${code}, message is ${message}`);
        })
    }
  }
}