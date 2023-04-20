declare module "*.svg" {
    const content: string;
    export default content;
}
declare module "*.css" {
    const content: string;
    export default content;
}

interface Window {
    onUserValuesChanged: any;
}

interface YoutubeUserScriptConfig {
    testMode?: "overlay-enabled",
    allowedOrigins: string[],
    webkitMessagingConfig: {
        secret: string,
        hasModernWebkitAPI: boolean,
        webkitMessageHandlerNames: string[]
    }
}

declare var $DDGYoutubeUserScriptConfig$: YoutubeUserScriptConfig;