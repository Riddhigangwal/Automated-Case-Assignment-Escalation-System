/**
 * @description Service class for handling case escalations
 * @author Your Name
 * @date 2024-12-15
 * @version 2.1.0
 */
public with sharing class EscalationService {
    
    private static final Integer HIGH_PRIORITY_ESCALATION_HOURS = 4;
    private static final Integer CRITICAL_PRIORITY_ESCALATION_HOURS = 1;
    private static final Integer MEDIUM_PRIORITY_ESCALATION_HOURS = 24;
    private static final Integer LOW_PRIORITY_ESCALATION_HOURS = 72;
    
    /**
     * @description Processes cases for automatic escalation based on SLA rules
     */
    @future
    public static void processAutomaticEscalations() {
        try {
            List<Case> casesToEscalate = findCasesForEscalation();
            
            for (Case caseRecord : casesToEscalate) {
                escalateCase(caseRecord, 'Automatic escalation due to SLA breach');
            }
            
            if (!casesToEscalate.isEmpty()) {
                update casesToEscalate;
            }
            
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'Error in automatic escalation: ' + e.getMessage());
            logError('EscalationService.processAutomaticEscalations', e.getMessage(), e.getStackTraceString());
        }
    }
    
    /**
     * @description Manually escalates a case with a specific reason
     * @param caseRecord The case to escalate
     * @param reason The reason for escalation
     */
    public static void escalateCase(Case caseRecord, String reason) {
        try {
            // Determine escalation target based on current owner and case attributes
            User escalationTarget = findEscalationTarget(caseRecord);
            
            if (escalationTarget != null) {
                // Update case fields
                caseRecord.OwnerId = escalationTarget.Id;
                caseRecord.Escalation_Level__c = getNextEscalationLevel(caseRecord.Escalation_Level__c);
                caseRecord.Escalation_Date__c = DateTime.now();
                caseRecord.Escalation_Reason__c = reason;
                caseRecord.Priority = escalatePriority(caseRecord.Priority);
                
                // Create escalation log
                createEscalationLog(caseRecord, escalationTarget, reason);
                
                // Send notification email
                sendEscalationNotification(caseRecord, escalationTarget, reason);
                
                System.debug('Case ' + caseRecord.CaseNumber + ' escalated to ' + escalationTarget.Name);
            } else {
                System.debug(LoggingLevel.WARN, 'No escalation target found for case: ' + caseRecord.CaseNumber);
            }
            
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'Error escalating case: ' + e.getMessage());
            logError('EscalationService.escalateCase', e.getMessage(), e.getStackTraceString());
        }
    }
    
    /**
     * @description Finds cases that need to be escalated based on SLA rules
     * @return List of cases to escalate
     */
    private static List<Case> findCasesForEscalation() {
        DateTime criticalThreshold = DateTime.now().addHours(-CRITICAL_PRIORITY_ESCALATION_HOURS);
        DateTime highThreshold = DateTime.now().addHours(-HIGH_PRIORITY_ESCALATION_HOURS);
        DateTime mediumThreshold = DateTime.now().addHours(-MEDIUM_PRIORITY_ESCALATION_HOURS);
        DateTime lowThreshold = DateTime.now().addHours(-LOW_PRIORITY_ESCALATION_HOURS);
        
        return [
            SELECT Id, CaseNumber, Priority, Type, Subject, OwnerId, Owner.Name, 
                   Escalation_Level__c, CreatedDate, Assignment_Date__c, 
                   Account.Name, Contact.Name, Contact.Email
            FROM Case 
            WHERE IsClosed = false 
            AND ((
                Priority = 'Critical' AND 
                (Assignment_Date__c <= :criticalThreshold OR 
                 (Assignment_Date__c = null AND CreatedDate <= :criticalThreshold))
            ) OR (
                Priority = 'High' AND 
                (Assignment_Date__c <= :highThreshold OR 
                 (Assignment_Date__c = null AND CreatedDate <= :highThreshold))
            ) OR (
                Priority = 'Medium' AND 
                (Assignment_Date__c <= :mediumThreshold OR 
                 (Assignment_Date__c = null AND CreatedDate <= :mediumThreshold))
            ) OR (
                Priority = 'Low' AND 
                (Assignment_Date__c <= :lowThreshold OR 
                 (Assignment_Date__c = null AND CreatedDate <= :lowThreshold))
            ))
            AND (Escalation_Level__c = null OR Escalation_Level__c != 'Level 3')
            ORDER BY Priority DESC, CreatedDate ASC
            LIMIT 50
        ];
    }
    
    /**
     * @description Finds the appropriate escalation target for a case
     * @param caseRecord The case to escalate
     * @return User to escalate to
     */
    private static User findEscalationTarget(Case caseRecord) {
        String currentEscalationLevel = caseRecord.Escalation_Level__c;
        String targetRole;
        
        // Determine target role based on current escalation level
        if (String.isBlank(currentEscalationLevel) || currentEscalationLevel == 'Level 1') {
            targetRole = 'Team Lead';
        } else if (currentEscalationLevel == 'Level 2') {
            targetRole = 'Manager';
        } else {
            targetRole = 'Director'; // Level 3 escalation
        }
        
        // Find available escalation target
        List<User> escalationTargets = [
            SELECT Id, Name, Email, Role__c
            FROM User 
            WHERE IsActive = true 
            AND Role__c = :targetRole
            AND Available_for_Escalation__c = true
            ORDER BY Current_Escalated_Cases__c ASC
            LIMIT 1
        ];
        
        return escalationTargets.isEmpty() ? null : escalationTargets[0];
    }
    
    /**
     * @description Gets the next escalation level
     * @param currentLevel Current escalation level
     * @return Next escalation level
     */
    private static String getNextEscalationLevel(String currentLevel) {
        if (String.isBlank(currentLevel)) {
            return 'Level 1';
        } else if (currentLevel == 'Level 1') {
            return 'Level 2';
        } else if (currentLevel == 'Level 2') {
            return 'Level 3';
        } else {
            return 'Level 3'; // Max escalation level
        }
    }
    
    /**
     * @description Escalates case priority if possible
     * @param currentPriority Current case priority
     * @return Escalated priority
     */
    private static String escalatePriority(String currentPriority) {
        if (currentPriority == 'Low') {
            return 'Medium';
        } else if (currentPriority == 'Medium') {
            return 'High';
        } else {
            return currentPriority; // Keep High and Critical as is
        }
    }
    
    /**
     * @description Creates an escalation log entry
     * @param caseRecord The escalated case
     * @param escalationTarget The user case was escalated to
     * @param reason The escalation reason
     */
    private static void createEscalationLog(Case caseRecord, User escalationTarget, String reason) {
        try {
            Escalation_Log__c log = new Escalation_Log__c(
                Case__c = caseRecord.Id,
                Escalated_To__c = escalationTarget.Id,
                Escalation_Date__c = DateTime.now(),
                Escalation_Level__c = caseRecord.Escalation_Level__c,
                Escalation_Reason__c = reason,
                Case_Priority__c = caseRecord.Priority,
                Original_Owner__c = caseRecord.OwnerId
            );
            
            insert log;
        } catch (Exception e) {
            System.debug(LoggingLevel.WARN, 'Failed to create escalation log: ' + e.getMessage());
        }
    }
    
    /**
     * @description Sends escalation notification email
     * @param caseRecord The escalated case
     * @param escalationTarget The user to notify
     * @param reason The escalation reason
     */
    private static void sendEscalationNotification(Case caseRecord, User escalationTarget, String reason) {
        try {
            // Get email template
            EmailTemplate template = [
                SELECT Id, Subject, Body 
                FROM EmailTemplate 
                WHERE DeveloperName = 'Case_Escalation_Notification' 
                LIMIT 1
            ];
            
            if (template != null) {
                Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
                email.setTargetObjectId(escalationTarget.Id);
                email.setTemplateId(template.Id);
                email.setWhatId(caseRecord.Id);
                email.setSaveAsActivity(false);
                
                // Add additional recipients if needed
                List<String> ccAddresses = new List<String>();
                if (caseRecord.Priority == 'Critical') {
                    ccAddresses.add('management@company.com');
                }
                
                if (!ccAddresses.isEmpty()) {
                    email.setCcAddresses(ccAddresses);
                }
                
                Messaging.sendEmail(new Messaging.SingleEmailMessage[] { email });
            }
            
        } catch (Exception e) {
            System.debug(LoggingLevel.WARN, 'Failed to send escalation notification: ' + e.getMessage());
        }
    }
    
    /**
     * @description Batch method to check and process escalations
     * Called by scheduled job
     */
    public static void batchProcessEscalations() {
        // Check business hours before processing
        if (isBusinessHours()) {
            processAutomaticEscalations();
        }
    }
    
    /**
     * @description Checks if current time is within business hours
     * @return True if within business hours
     */
    private static Boolean isBusinessHours() {
        try {
            BusinessHours bh = [
                SELECT Id FROM BusinessHours 
                WHERE IsDefault = true LIMIT 1
            ];
            
            return BusinessHours.isWithin(bh.Id, DateTime.now());
        } catch (Exception e) {
            // If business hours not configured, assume always business hours
            return true;
        }
    }
    
    /**
     * @description Logs errors to custom error log object
     * @param className The class where error occurred
     * @param errorMessage The error message
     * @param stackTrace The stack trace
     */
    private static void logError(String className, String errorMessage, String stackTrace) {
        try {
            Error_Log__c errorLog = new Error_Log__c(
                Class_Name__c = className,
                Error_Message__c = errorMessage,
                Stack_Trace__c = stackTrace,
                Error_Date__c = DateTime.now(),
                User__c = UserInfo.getUserId()
            );
            
            insert errorLog;
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'Failed to log error: ' + e.getMessage());
        }
    }
}

