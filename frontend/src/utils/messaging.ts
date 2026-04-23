const shouldLogMessage = (message: string, hasBridge: boolean): boolean =>
  !hasBridge || message === 'runLintNow' || message === 'MessageListenerRegistered';

const sendDiag = (event: string, detail: string): void => {
  const url = `./api/diag?source=frontend&event=${encodeURIComponent(event)}&detail=${encodeURIComponent(detail)}`;
  void fetch(url).catch(() => {
    // Ignore diagnostics failures to avoid impacting user actions.
  });
};

type ExtensionMessageResponse = {
  success?: boolean;
  error?: string;
};

export const sendExtensionMessage = async (message: string, data?: unknown): Promise<ExtensionMessageResponse> => {
  const webview = window.chrome?.webview;
  const hasBridge = !!webview;

  if (shouldLogMessage(message, hasBridge)) {
    const detail = `message=${message};hasBridge=${hasBridge};href=${window.location.href}`;
    sendDiag('postMessageAttempt', detail);
  }

  if (hasBridge) {
    webview.postMessage({ message, data });
    return { success: true };
  }

  try {
    const response = await fetch('./api/message', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ message, data }),
    });

    if (!response.ok) {
      return { success: false, error: `Message dispatch failed (${response.status})` };
    }

    return await response.json() as ExtensionMessageResponse;
  } catch (error) {
    const err = error instanceof Error ? error.message : 'Message dispatch failed.';
    return { success: false, error: err };
  }
};

export const postMessage = (message: string, data?: unknown): void => {
  void sendExtensionMessage(message, data);
};
