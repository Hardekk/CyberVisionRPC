#include "CyberVisionRPC/bindings.h"
#include "CyberVisionRPC/discordrpc.h"

#include <chrono>

static RED4ext::TTypedClass<CyberVisionRPC::Bindings::DiscordRPC> g_DiscordRPCClass("CyberVisionRPC.DiscordRPC");

void CyberVisionRPC::Bindings::DiscordRPC_IsRunning(RED4ext::IScriptable* aContext, RED4ext::CStackFrame* aFrame, bool* aOut, int64_t a4)
{
    aFrame->code++;
    if (aOut)
        *aOut = CyberVisionRPC::DiscordRPC::GetInstance()->IsRunning();
}

void CyberVisionRPC::Bindings::DiscordRPC_IsConnected(RED4ext::IScriptable* aContext, RED4ext::CStackFrame* aFrame, bool* aOut, int64_t a4)
{
    aFrame->code++;
    if (aOut)
        *aOut = CyberVisionRPC::DiscordRPC::GetInstance()->IsConnected();
}

void CyberVisionRPC::Bindings::DiscordRPC_IsOk(RED4ext::IScriptable* aContext, RED4ext::CStackFrame* aFrame, bool* aOut, int64_t a4)
{
    aFrame->code++;
    if (aOut)
        *aOut = CyberVisionRPC::DiscordRPC::GetInstance()->IsOk();
}

void CyberVisionRPC::Bindings::DiscordRPC_GetLastRunCallbacksResult(RED4ext::IScriptable* aContext, RED4ext::CStackFrame* aFrame, int32_t* aOut, int64_t a4)
{
    aFrame->code++;
    if (aOut)
        *aOut = CyberVisionRPC::DiscordRPC::GetInstance()->GetLastRunCallbacksResult();
}

void CyberVisionRPC::Bindings::DiscordRPC_GetTime(RED4ext::IScriptable* aContext, RED4ext::CStackFrame* aFrame, uint64_t* aOut, int64_t a4)
{
    aFrame->code++;
    if (aOut)
        *aOut = std::chrono::duration_cast<std::chrono::seconds>(std::chrono::system_clock::now().time_since_epoch()).count();
}

void CyberVisionRPC::Bindings::DiscordRPC_UpdateActivity(RED4ext::IScriptable* aContext, RED4ext::CStackFrame* aFrame, bool* aOut, int64_t a4)
{
    DiscordActivity activity;
    RED4ext::GetParameter(aFrame, &activity);
    aFrame->code++;

    auto retVal = CyberVisionRPC::DiscordRPC::GetInstance()->UpdateActivity(activity);
    if (aOut)
        *aOut = retVal;
}

void CyberVisionRPC::Bindings::DiscordRPC_ClearActivity(RED4ext::IScriptable* aContext, RED4ext::CStackFrame* aFrame, bool* aOut, int64_t a4)
{
    aFrame->code++;

    auto retVal = CyberVisionRPC::DiscordRPC::GetInstance()->ClearActivity();
    if (aOut)
        *aOut = retVal;
}

RED4ext::CClass* CyberVisionRPC::Bindings::DiscordRPC::GetNativeType()
{
    return &g_DiscordRPCClass;
}

void CyberVisionRPC::Bindings::RegisterTypes()
{
    RED4ext::CRTTISystem::Get()->RegisterType(&g_DiscordRPCClass);
}

void CyberVisionRPC::Bindings::PostRegisterTypes()
{
    auto rtti = RED4ext::CRTTISystem::Get();
    auto scriptable = rtti->GetClass("IScriptable");
    g_DiscordRPCClass.parent = scriptable;

    // === Discord::IsRunning ===
    auto isRunning = RED4ext::CClassStaticFunction::Create(&g_DiscordRPCClass,
        "IsRunning", "IsRunning", &DiscordRPC_IsRunning);
    isRunning->SetReturnType("Bool");
    g_DiscordRPCClass.RegisterFunction(isRunning);

    // === Discord::IsConnected ===
    auto isConnected = RED4ext::CClassStaticFunction::Create(&g_DiscordRPCClass,
        "IsConnected", "IsConnected", &DiscordRPC_IsConnected);
    isConnected->SetReturnType("Bool");
    g_DiscordRPCClass.RegisterFunction(isConnected);

    // === Discord::IsOk ===
    auto isOk = RED4ext::CClassStaticFunction::Create(&g_DiscordRPCClass,
        "IsOk", "IsOk", &DiscordRPC_IsOk);
    isOk->SetReturnType("Bool");
    g_DiscordRPCClass.RegisterFunction(isOk);

    // === Discord::GetLastRunCallbacksResult ===
    auto getLastRunCallbacksResult = RED4ext::CClassStaticFunction::Create(&g_DiscordRPCClass,
        "GetLastRunCallbacksResult", "GetLastRunCallbacksResult", &DiscordRPC_GetLastRunCallbacksResult);
    getLastRunCallbacksResult->SetReturnType("Int32");
    g_DiscordRPCClass.RegisterFunction(getLastRunCallbacksResult);

    // === GetTime ===
    auto getTime = RED4ext::CClassStaticFunction::Create(&g_DiscordRPCClass,
        "GetTime", "GetTime", &DiscordRPC_GetTime);
    getTime->SetReturnType("Uint64");
    g_DiscordRPCClass.RegisterFunction(getTime);

    // === Discord::UpdateActivity ===
    auto updateActivity = RED4ext::CClassStaticFunction::Create(&g_DiscordRPCClass,
        "UpdateActivity", "UpdateActivity", &DiscordRPC_UpdateActivity);
    updateActivity->AddParam("DiscordActivity", "activity");
    updateActivity->SetReturnType("Bool");
    g_DiscordRPCClass.RegisterFunction(updateActivity);

    // === Discord::ClearActivity ===
    auto clearActivity = RED4ext::CClassStaticFunction::Create(&g_DiscordRPCClass,
        "ClearActivity", "ClearActivity", &DiscordRPC_ClearActivity);
    clearActivity->SetReturnType("Bool");
    g_DiscordRPCClass.RegisterFunction(clearActivity);
}
