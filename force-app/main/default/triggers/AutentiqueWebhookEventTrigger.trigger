trigger AutentiqueWebhookEventTrigger on AutentiqueWebhookEvent__e (after insert) {
    AutentiqueWebhookEventHandler.handle(Trigger.new);
}