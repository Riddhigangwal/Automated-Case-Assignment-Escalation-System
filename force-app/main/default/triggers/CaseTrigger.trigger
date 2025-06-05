/**
 * @description Trigger for Case object to handle automatic assignment and escalation
 * @author Your Name
 * @date 2024-12-15
 * @version 2.1.0
 */
trigger CaseTrigger on Case (before insert, before update, after insert, after update) {
    
    // Trigger handler to organize the logic
    CaseTriggerHandler handler = new CaseTriggerHandler();
    
    if (Trigger.isBefore) {
        if (Trigger.isInsert) {
            handler.beforeInsert(Trigger.new);
        } else if (Trigger.isUpdate) {
            handler.beforeUpdate(Trigger.new, Trigger.oldMap);
        }
    } else if (Trigger.isAfter) {
        if (Trigger.isInsert) {
            handler.afterInsert(Trigger.new);
        } else if (Trigger.isUpdate) {
            handler.afterUpdate(Trigger.new, Trigger.oldMap);
        }
    }
}

