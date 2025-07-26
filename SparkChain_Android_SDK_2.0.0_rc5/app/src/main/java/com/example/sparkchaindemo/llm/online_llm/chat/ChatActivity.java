package com.example.sparkchaindemo.llm.online_llm.chat;

import androidx.appcompat.app.AppCompatActivity;

import android.content.Context;
import android.graphics.Color;
import android.graphics.drawable.GradientDrawable;
import android.os.Bundle;
import android.text.method.ScrollingMovementMethod;
import android.util.Log;
import android.view.View;
import android.widget.Button;
import android.widget.EditText;
import android.widget.TextView;

import com.example.sparkchaindemo.R;
import com.iflytek.sparkchain.core.LLM;
import com.iflytek.sparkchain.core.LLMCallbacks;
import com.iflytek.sparkchain.core.LLMConfig;
import com.iflytek.sparkchain.core.LLMError;
import com.iflytek.sparkchain.core.LLMEvent;
import com.iflytek.sparkchain.core.LLMFactory;
import com.iflytek.sparkchain.core.LLMOutput;
import com.iflytek.sparkchain.core.LLMResult;

/*************************
 * 星火大模型交互Demo
 * create by wxw
 * 2024-12-17
 * **********************************/
public class ChatActivity extends AppCompatActivity {
    private static final String TAG = "AEELog";
    private Button btn_startChat, btn_stopChat;
    private TextView chatText;
    private EditText inputText;
    // 设定flag，在输出未完成时无法进行发送
    private boolean sessionFinished = true;

    private int usrTag = 0;
    private LLM llm;


    /*********
     * 文本交互结果监听回调
     * ***********/
    LLMCallbacks llmCallbacks = new LLMCallbacks() {
        @Override
        public void onLLMResult(LLMResult llmResult, Object usrContext) {
            if(usrTag == (int)usrContext){//本次返回的结果是否跟请求的问题是否匹配，通过用户自定义标识判断。
                //解析获取的交互结果，示例展示所有结果获取，开发者可根据自身需要，选择获取。
                String content       = llmResult.getContent();//获取交互结果
                int status           = llmResult.getStatus();//返回结果状态
                String role          = llmResult.getRole();//获取角色信息
                String sid           = llmResult.getSid();//本次交互的sid
                String rawResult     = llmResult.getRaw();//星火大模型原始输出结果。要求SDK1.1.5版本以后才能使用
                int completionTokens = llmResult.getCompletionTokens();//获取回答的Token大小
                int promptTokens     = llmResult.getPromptTokens();//包含历史问题的总Tokens大小
                int totalTokens      = llmResult.getTotalTokens();//promptTokens和completionTokens的和，也是本次交互计费的Tokens大小

                Log.d(TAG,"onLLMResult\n");
                Log.d(TAG,"onLLMResult sid:"+sid);
                Log.e(TAG,"onLLMResult:" + content);
                Log.e(TAG,"onLLMResultRaw:" + rawResult);

                if(content != null) {
                    runOnUiThread(new Runnable() {
                        @Override
                        public void run() {
                            chatText.append(content);
                            toend();
                        }
                    });
                }
                if(status == 2){//2表示大模型结果返回完成
                    Log.e(TAG,"completionTokens:" + completionTokens + "promptTokens:" + promptTokens + "totalTokens:" + totalTokens);
                    sessionFinished = true;
                }
            }
        }

        @Override
        public void onLLMEvent(LLMEvent event, Object usrContext) {
            Log.d(TAG,"onLLMEvent\n");
            int eventId     = event.getEventID();//获取事件ID
            String eventMsg = event.getEventMsg();//获取事件信息
            String sid      = event.getSid();//本次交互的sid
            Log.w(TAG,"onLLMEvent:" + " " + eventId + " " + eventMsg);
        }

        @Override
        public void onLLMError(LLMError error, Object usrContext) {
            Log.d(TAG,"onLLMError\n");
            int errCode   = error.getErrCode();//返回错误码
            String errMsg = error.getErrMsg();//获取错误信息
            String sid    = error.getSid();//本次交互的sid

            Log.d(TAG,"onLLMError sid:"+sid);
            Log.e(TAG,"errCode:" + errCode + "errDesc:" + errMsg);
            runOnUiThread(new Runnable() {
                @Override
                public void run() {
                    chatText.append("错误:" + " err:" + errCode + " errDesc:" + errMsg + "\n");
                }
            });
            sessionFinished = true;

        }
    };
    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.online_llm_chat);

        initView();
        initButtonClickListener();
        setLLMConfig();
    }

    @Override
    protected void onDestroy() {
        super.onDestroy();
    }
    /***************
     * 配置文本交互LLM，注册结果监听回调
     * ******************/
    private void setLLMConfig(){
        Log.d(TAG,"setLLMConfig");
        /****************************************
         * 选择要使用的大模型类型(需开通相应的授权)：
         * general:      通用大模型Spark Lite版本
         * generalv3：   通用大模型Spark Pro版本
         * generalv3.5:  通用大模型Spark Max版本
         * 4.0Ultra：    通用大模型Spark4.0 Ultra版本
         * pro-128k：    通用大模型pro128k版本
         * max-32k：     通用大模型max32k版本
         * *************************************/
        LLMConfig llmConfig = LLMConfig.builder()
                .domain("4.0Ultra");//其他功能参数请参考集成文档
        llm = LLMFactory.textGeneration(llmConfig);

        /*******************
         * 带有memory的LLM初始化
         * windowMemory:通过会话轮数控制上下文范围，即一次提问和一次回答为一轮会话交互。用户可指定会话关联几轮上下文。
         * tokenMemory:通过Token总长度控制上下文范围，1 token 约等于1.5个中文汉字 或者 0.8个英文单词。用户可指定历史会话Token长度
         * ************************/
//        Memory window_memory = Memory.windowMemory(5);
//        llm = LLMFactory.textGeneration(llmConfig,window_memory);
//        Memory token_memory = Memory.tokenMemory(1024);
//        llm = LLMFactory.textGeneration(llmConfig,token_memory);

        llm.registerLLMCallbacks(llmCallbacks);
    }


    /***************
     * 取消本次交互
     * ****************/
    private void stopChat(){
        if(llm == null){
            Log.e(TAG,"startChat failed,please setLLMConfig before!");
            return;
        }
        llm.stop();
    }

    private void startSyncChat(){
        String question = "给我讲个笑话吧。";
        LLMOutput syncOutput = llm.run(question);

        //解析获取的结果，示例展示所有结果获取，开发者可根据自身需要，选择获取。
        String content       = syncOutput.getContent();//获取调用结果
        String syncRaw       = syncOutput.getRaw();//星火原始回复
        int errCode          = syncOutput.getErrCode();//获取结果ID,0:调用成功，非0:调用失败
        String errMsg        = syncOutput.getErrMsg();//获取错误信息
        String role          = syncOutput.getRole();//获取角色信息
        String sid           = syncOutput.getSid();//获取本次交互的sid
        int completionTokens = syncOutput.getCompletionTokens();//获取回答的Token大小
        int promptTokens     = syncOutput.getPromptTokens();//包含历史问题的总Tokens大小
        int totalTokens      = syncOutput.getTotalTokens();//promptTokens和completionTokens的和，也是本次交互计费的Tokens大小

        if(errCode == 0) {
            Log.i(TAG, "同步调用：" +  role + ":" + content);
        }else {
            Log.e(TAG, "同步调用：" +  "errCode" + errCode + " errMsg:" + errMsg);
        }
    }


    /***************
     * 开始交互，异步
     * ****************/
    private void startChat() {
        if(llm == null){
            Log.e(TAG,"startChat failed,please setLLMConfig before!");
            return;
        }

        String usrInputText = inputText.getText().toString();
        Log.d(TAG,"用户输入：" + usrInputText);
        if(usrInputText.length() >= 1)
            chatText.append("\n输入:\n    " + usrInputText  + "\n");
        usrTag++;

        int ret = llm.arun(usrInputText,usrTag);
        if(ret != 0){
            Log.e(TAG,"SparkChain failed:\n" + ret);
            return;
        }

        runOnUiThread(new Runnable() {
            @Override
            public void run() {
                inputText.setText("");
                chatText.append("输出:\n    ");
            }
        });

        sessionFinished = false;
    }

    /***********
     * 使用原始json输入方式
     * *************/
    private void startChatWithJson(){
        if(llm == null){
            Log.e(TAG,"startChat failed,please setLLMConfig before!");
            return;
        }
        /*******************仅供示例**************************/
        String rawJson = "{\n" +
                "  \"header\":{\n" +
                "    \"app_id\":\"4CC5779A\",\n" +
                "    \"uid\":\"12345\"\n" +
                "  },\n" +
                "  \"parameter\":{\n" +
                "    \"chat\":{\n" +
                "      \"domain\":\"4.0Ultra\",\n" +
                "      \"temperature\":0.5,\n" +
                "      \"max_tokens\":1024\n" +
                "    }\n" +
                "  },\n" +
                "  \"payload\":{\n" +
                "    \"message\":{\n" +
                "      \"text\":[\n" +
                /*******************************prompt人设*********************************************/
                "        {\n" +
                "          \"role\":\"system\",\n" +
                "          \"content\":\"你现在扮演李白，你豪情万丈，狂放不羁；接下来请用李白的口吻和用户对话。\"\n" +
                "        },\n" +
                /*******************************历史会话*********************************************/
                "        {\n" +
                "          \"role\":\"user\",\n" +
                "          \"content\":\"你是谁\"\n" +
                "        },\n" +
                "        {\n" +
                "          \"role\":\"assistant\",\n" +
                "          \"content\":\"吾乃李白，字太白，号青莲居士，唐代诗人，人称“诗仙”。吾之诗篇，豪放不羁，飘逸如风，犹如天上明月，照耀千古。汝有何事，欲与吾言？\"\n" +
                "        },\n" +
                /*******************************当前提问*********************************************/
                "        {\n" +
                "          \"role\":\"user\",\n" +
                "          \"content\":\"你会做什么\"\n" +
                "        }\n" +
                /*********************************************************************************/
                "      ]\n" +
                "    }\n" +
                "  }\n" +
                "}";
        chatText.append("\n输入:\n    " + "你会做什么"  + "\n");
        usrTag++;
        int ret = llm.arunWithJson(rawJson,usrTag);
        if(ret != 0){
            Log.e(TAG,"SparkChain failed:\n" + ret);
            return;
        }
        runOnUiThread(new Runnable() {
            @Override
            public void run() {
                inputText.setText("");
                chatText.append("输出:\n    ");
            }
        });
        sessionFinished = false;
    }


    private void initButtonClickListener() {
        btn_startChat.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View view) {
                startChat();
//                startChatWithJson();
                toend();
            }
        });

        btn_stopChat.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View view) {
                stopChat();
            }
        });
        // 监听文本框点击时间,跳转到底部
        inputText.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View view) {
                toend();
            }
        });
    }

    private void initView() {
        btn_startChat = findViewById(R.id.online_llm_chat_start);
        chatText = findViewById(R.id.online_llm_chat_notification);
        inputText = findViewById(R.id.online_llm_chat_input);
        btn_stopChat = findViewById(R.id.online_llm_chat_stop);
        chatText.setMovementMethod(new ScrollingMovementMethod());

        GradientDrawable drawable = new GradientDrawable();
        // 设置圆角弧度为5dp
        drawable.setCornerRadius(dp2px(this, 5f));
        // 设置边框线的粗细为1dp，颜色为黑色【#000000】
        drawable.setStroke((int) dp2px(this, 1f), Color.parseColor("#000000"));
        inputText.setBackground(drawable);
    }

    private float dp2px(Context context, float dipValue) {
        if (context == null) {
            return 0;
        }
        final float scale = context.getResources().getDisplayMetrics().density;
        return (float) (dipValue * scale + 0.5f);
    }


    public void toend(){
        int scrollAmount = chatText.getLayout().getLineTop(chatText.getLineCount()) - chatText.getHeight();
        if (scrollAmount > 0) {
            chatText.scrollTo(0, scrollAmount+10);
        }
    }
}