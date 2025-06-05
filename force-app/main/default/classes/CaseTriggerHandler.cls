/**
 * @description Handler class for Case trigger operations
 * @author Your Name
 * @date 2024-12-15
 * @version 2.1.0
 */
public with sharing class CaseTriggerHandler {
    
    private static Boolean isExecuting = false;
    
    /**
     * @description Handles before insert operations
     * @param newCases List of new cases being inserted
     */
    public void beforeInsert(List<Case> newCases) {
        if (isExecuting) return;
        isExecuting = true;
        
        try {
            // Set default values and validate case data
            setDefaultValues(newCases);
            
            // Apply business rules
            applyBusinessRules(newCases);
            
        } finally {
            isExecuting = false;
        }
    }
    
    /**
     * @description Handles before update operations
     * @param newCases List of updated cases
     * @param oldCaseMap Map of old case values
     */
    public void beforeUpdate(List<Case> newCases, Map<Id, Case> oldCaseMap) {
        if (isExecuting) return;
        isExecuting = true;
        
        try {
            // Update case fields based on changes
            handleStatusChanges(newCases, oldCaseMap);
            
            // Apply business rules
            applyBusinessRules(newCases);
            
        } finally {
            isExecuting = false;
        }
    }
    
    /**
     * @description Handles after insert operations
     * @param newCases List of newly inserted cases
     */
    public void afterInsert(List<Case> newCases) {
        if (isExecuting) return;
        isExecuting = true;
        
        try {
            // Trigger automatic assignment for new cases
            List<Case> casesForAssignment = filterCasesForAssignment(newCases);
            if (!casesForAssignment.isEmpty()) {
                CaseAssignmentHandler.assignCases(casesForAssignment);
            }
            
            // Send notifications for high priority cases
            sendHighPriorityNotifications(newCases);
            
        } finally {
            isExecuting = false;
        }
    }
    
    /**
     * @description Handles after update operations
     * @param newCases List of updated cases
     * @param oldCaseMap Map of old case values
     */
    public void afterUpdate(List<Case> newCases, Map<Id, Case> oldCaseMap) {
        if (isExecuting) return;
        isExecuting = true;
        
        try {
            // Check for priority escalations
            List<Case> escalatedCases = findPriorityEscalations(newCases, oldCaseMap);
            if (!escalatedCases.isEmpty()) {
                handlePriorityEscalations(escalatedCases);
            }
            
            // Handle ownership changes
            handleOwnershipChanges(newCases, oldCaseMap);
            
            // Update related records
            updateRelatedRecords(newCases, oldCaseMap);
            
        } finally {
            isExecuting = false;
        }
    }
    
    /**
     * @description Sets default values for new cases
     * @param cases List of cases to process
     */
    private void setDefaultValues(List<Case> cases) {
        for (Case caseRecord : cases) {
            // Set default priority if not specified
            if (String.isBlank(caseRecord.Priority)) {
                caseRecord.Priority = 'Medium';
            }
            
            // Set default type if not specified
            if (String.isBlank(caseRecord.Type)) {
                caseRecord.Type = 'General';
            }
            
            // Set creation source if from email
            if (caseRecord.SuppliedEmail != null && String.isBlank(caseRecord.Origin)) {
                caseRecord.Origin = 'Email';
            }
            
            // Initialize custom fields
            if (caseRecord.SLA_Start_Time__c == null) {
                caseRecord.SLA_Start_Time__c = DateTime.now();
            }
            
            if (String.isBlank(caseRecord.Escalation_Level__c)) {
                caseRecord.Escalation_Level__c = 'Level 0';
            }
        }
    }
    
    /**
     * @description Applies business rules to cases
     * @param cases List of cases to process
     */
    private void applyBusinessRules(List<Case> cases) {
        for (Case caseRecord : cases) {
            // Auto-escalate based on customer tier
            if (caseRecord.Account.Type == 'Customer - Channel' && 
                caseRecord.Priority != 'Critical') {
                caseRecord.Priority = 'High';
            }
            
            // Set SLA based on priority
            setSLATargets(caseRecord);
            
            // Validate required fields based on type
            validateRequiredFields(caseRecord);
        }
    }
    
    /**
     * @description Sets SLA targets based on case priority
     * @param caseRecord The case to set SLA for
     */
    private void setSLATargets(Case caseRecord) {
        Integer responseHours = 0;
        Integer resolutionHours = 0;
        
        switch on caseRecord.Priority {
            when 'Critical' {
                responseHours = 1;
                resolutionHours = 4;
            }
            when 'High' {
                responseHours = 4;
                resolutionHours = 24;
            }
            when 'Medium' {
                responseHours = 24;
                resolutionHours = 72;
            }
            when 'Low' {
                responseHours = 72;
                resolutionHours = 168; // 1 week
            }
        }
        
        if (caseRecord.SLA_Start_Time__c != null) {
            caseRecord.Response_SLA_Target__c = caseRecord.SLA_Start_Time__c.addHours(responseHours);
            caseRecord.Resolution_SLA_Target__c = caseRecord.SLA_Start_Time__c.addHours(resolutionHours);
        }
    }
    
    /**
     * @description Validates required fields based on case type
     * @param caseRecord The case to validate
     */
    private void validateRequiredFields(Case caseRecord) {
        if (caseRecord.Type == 'Technical' && String.isBlank(caseRecord.Product__c)) {
            caseRecord.addError('Product field is required for Technical cases.');
        }
        
        if (caseRecord.Priority == 'Critical' && String.isBlank(caseRecord.Business_Impact__c)) {
            caseRecord.addError('Business Impact is required for Critical priority cases.');
        }
    }
    
    /**
     * @description Handles case status changes
     * @param newCases List of updated cases
     * @param oldCaseMap Map of old case values
     */
    private void handleStatusChanges(List<Case> newCases, Map<Id, Case> oldCaseMap) {
        for (Case caseRecord : newCases) {
            Case oldCase = oldCaseMap.get(caseRecord.Id);
            
            // Track first response time
            if (oldCase.Status == 'New' && caseRecord.Status != 'New' && 
                caseRecord.First_Response_Time__c == null) {
                caseRecord.First_Response_Time__c = DateTime.now();
            }
            
            // Track resolution time
            if (!oldCase.IsClosed && caseRecord.IsClosed && 
                caseRecord.Resolution_Time__c == null) {
                caseRecord.Resolution_Time__c = DateTime.now();
            }
            
            // Reset escalation level if case is reopened
            if (oldCase.IsClosed && !caseRecord.IsClosed) {
                caseRecord.Escalation_Level__c = 'Level 0';
                caseRecord.SLA_Start_Time__c = DateTime.now();
                setSLATargets(caseRecord);
            }
        }
    }
    
    /**
     * @description Filters cases that need automatic assignment
     * @param cases List of cases to filter
     * @return List of cases needing assignment
     */
    private List<Case> filterCasesForAssignment(List<Case> cases) {
        List<Case> casesForAssignment = new List<Case>();
        
        for (Case caseRecord : cases) {
            // Assign if no owner or owner is a queue
            if (caseRecord.OwnerId == null || 
                String.valueOf(caseRecord.OwnerId).startsWith('00G')) {
                casesForAssignment.add(caseRecord);
            }
        }
        
        return casesForAssignment;
    }
    
    /**
     * @description Sends notifications for high priority cases
     * @param cases List of cases to check
     */
    private void sendHighPriorityNotifications(List<Case> cases) {
        List<Case> highPriorityCases = new List<Case>();
        
        for (Case caseRecord : cases) {
            if (caseRecord.Priority == 'Critical' || caseRecord.Priority == 'High') {
                highPriorityCases.add(caseRecord);
            }
        }
        
        if (!highPriorityCases.isEmpty()) {
            // Send notifications asynchronously
            NotificationService.sendHighPriorityNotifications(highPriorityCases);
        }
    }
    
    /**
     * @description Finds cases that had priority escalated
     * @param newCases List of updated cases
     * @param oldCaseMap Map of old case values
     * @return List of escalated cases
     */
    private List<Case> findPriorityEscalations(List<Case> newCases, Map<Id, Case> oldCaseMap) {
        List<Case> escalatedCases = new List<Case>();
        
        for (Case caseRecord : newCases) {
            Case oldCase = oldCaseMap.get(caseRecord.Id);
            
            // Check if priority was escalated
            if (isPriorityEscalated(oldCase.Priority, caseRecord.Priority)) {
                escalatedCases.add(caseRecord);
            }
        }
        
        return escalatedCases;
    }
    
    /**
     * @description Checks if priority was escalated
     * @param oldPriority Previous priority
     * @param newPriority New priority
     * @return True if escalated
     */
    private Boolean isPriorityEscalated(String oldPriority, String newPriority) {
        Map<String, Integer> priorityLevels = new Map<String, Integer>{
            'Low' => 1,
            'Medium' => 2,
            'High' => 3,
            'Critical' => 4
        };
        
        Integer oldLevel = priorityLevels.get(oldPriority);
        Integer newLevel = priorityLevels.get(newPriority);
        
        return oldLevel != null && newLevel != null && newLevel > oldLevel;
    }
    
    /**
     * @description Handles priority escalations
     * @param escalatedCases List of cases with escalated priority
     */
    private void handlePriorityEscalations(List<Case> escalatedCases) {
        for (Case caseRecord : escalatedCases) {
            // Update SLA targets for new priority
            setSLATargets(caseRecord);
            
            // Trigger reassignment if needed
            if (caseRecord.Priority == 'Critical') {
                // Critical cases should go to senior agents
                // This will be handled by the assignment rules
            }
        }
    }
    
    /**
     * @description Handles ownership changes
     * @param newCases List of updated cases
     * @param oldCaseMap Map of old case values
     */
    private void handleOwnershipChanges(List<Case> newCases, Map<Id, Case> oldCaseMap) {
        for (Case caseRecord : newCases) {
            Case oldCase = oldCaseMap.get(caseRecord.Id);
            
            // Track ownership changes
            if (caseRecord.OwnerId != oldCase.OwnerId) {
                caseRecord.Last_Owner_Change__c = DateTime.now();
                caseRecord.Previous_Owner__c = oldCase.OwnerId;
            }
        }
    }
    
    /**
     * @description Updates related records when case changes
     * @param newCases List of updated cases
     * @param oldCaseMap Map of old case values
     */
    private void updateRelatedRecords(List<Case> newCases, Map<Id, Case> oldCaseMap) {
        // This method can be extended to update related objects
        // like Knowledge Articles, Assets, etc.
        
        List<Case> closedCases = new List<Case>();
        
        for (Case caseRecord : newCases) {
            Case oldCase = oldCaseMap.get(caseRecord.Id);
            
            if (!oldCase.IsClosed && caseRecord.IsClosed) {
                closedCases.add(caseRecord);
            }
        }
        
        if (!closedCases.isEmpty()) {
            // Update customer satisfaction survey requests
            // updateSatisfactionSurveys(closedCases);
        }
    }
}

