/**
 * @description Handler class for automated case assignment logic
 * @author Your Name
 * @date 2024-12-15
 * @version 2.1.0
 */
public with sharing class CaseAssignmentHandler {
    
    private static final String TECHNICAL_QUEUE = 'Technical_Support';
    private static final String BILLING_QUEUE = 'Billing_Support';
    private static final String GENERAL_QUEUE = 'General_Support';
    
    /**
     * @description Assigns cases to appropriate agents based on case type and priority
     * @param cases List of cases to assign
     */
    public static void assignCases(List<Case> cases) {
        try {
            List<Case> casesToUpdate = new List<Case>();
            Map<String, List<User>> agentsBySkill = getAvailableAgentsBySkill();
            
            for (Case caseRecord : cases) {
                if (caseRecord.OwnerId == null || isQueue(caseRecord.OwnerId)) {
                    User assignedAgent = findBestAgent(caseRecord, agentsBySkill);
                    if (assignedAgent != null) {
                        caseRecord.OwnerId = assignedAgent.Id;
                        caseRecord.Assignment_Date__c = DateTime.now();
                        caseRecord.Assignment_Method__c = 'Automated';
                        casesToUpdate.add(caseRecord);
                        
                        // Log assignment for audit trail
                        createAssignmentLog(caseRecord, assignedAgent);
                    }
                }
            }
            
            if (!casesToUpdate.isEmpty()) {
                update casesToUpdate;
            }
            
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'Error in case assignment: ' + e.getMessage());
            // Log error to custom object for monitoring
            logError('CaseAssignmentHandler.assignCases', e.getMessage(), e.getStackTraceString());
        }
    }
    
    /**
     * @description Finds the best available agent for a case based on skills and workload
     * @param caseRecord The case to assign
     * @param agentsBySkill Map of available agents by skill
     * @return Best suited agent or null if none available
     */
    private static User findBestAgent(Case caseRecord, Map<String, List<User>> agentsBySkill) {
        String requiredSkill = determineRequiredSkill(caseRecord);
        List<User> availableAgents = agentsBySkill.get(requiredSkill);
        
        if (availableAgents == null || availableAgents.isEmpty()) {
            // Fallback to general support agents
            availableAgents = agentsBySkill.get('General');
        }
        
        if (availableAgents != null && !availableAgents.isEmpty()) {
            // Sort agents by current workload and priority handling capability
            return selectAgentByWorkload(availableAgents, caseRecord.Priority);
        }
        
        return null;
    }
    
    /**
     * @description Determines required skill based on case attributes
     * @param caseRecord The case to analyze
     * @return Required skill string
     */
    private static String determineRequiredSkill(Case caseRecord) {
        if (caseRecord.Type == 'Technical' || caseRecord.Subject.containsIgnoreCase('API') || 
            caseRecord.Subject.containsIgnoreCase('Integration')) {
            return 'Technical';
        } else if (caseRecord.Type == 'Billing' || caseRecord.Subject.containsIgnoreCase('Payment') ||
                   caseRecord.Subject.containsIgnoreCase('Invoice')) {
            return 'Billing';
        } else {
            return 'General';
        }
    }
    
    /**
     * @description Selects agent based on current workload and capability
     * @param agents List of available agents
     * @param priority Case priority
     * @return Selected agent
     */
    private static User selectAgentByWorkload(List<User> agents, String priority) {
        // Get current case counts for each agent
        Map<Id, Integer> agentWorkload = getCurrentWorkload(agents);
        
        User bestAgent = null;
        Integer lowestWorkload = Integer.MAX_VALUE;
        
        for (User agent : agents) {
            Integer currentWorkload = agentWorkload.get(agent.Id);
            
            // Prioritize senior agents for high priority cases
            if (priority == 'High' || priority == 'Critical') {
                if (agent.Experience_Level__c == 'Senior' || agent.Experience_Level__c == 'Expert') {
                    if (currentWorkload < lowestWorkload) {
                        bestAgent = agent;
                        lowestWorkload = currentWorkload;
                    }
                }
            } else {
                // Round-robin for other priorities
                if (currentWorkload < lowestWorkload) {
                    bestAgent = agent;
                    lowestWorkload = currentWorkload;
                }
            }
        }
        
        // If no senior agent available for high priority, assign to least busy agent
        if (bestAgent == null && (priority == 'High' || priority == 'Critical')) {
            for (User agent : agents) {
                Integer currentWorkload = agentWorkload.get(agent.Id);
                if (currentWorkload < lowestWorkload) {
                    bestAgent = agent;
                    lowestWorkload = currentWorkload;
                }
            }
        }
        
        return bestAgent;
    }
    
    /**
     * @description Gets available agents grouped by their skills
     * @return Map of skill to list of agents
     */
    private static Map<String, List<User>> getAvailableAgentsBySkill() {
        Map<String, List<User>> agentsBySkill = new Map<String, List<User>>();
        
        // Query active support agents with their skills
        List<User> agents = [
            SELECT Id, Name, Skills__c, Experience_Level__c, Max_Cases__c, Timezone__c
            FROM User 
            WHERE IsActive = true 
            AND Profile.Name LIKE '%Support%'
            AND Available_for_Assignment__c = true
            ORDER BY Experience_Level__c DESC
        ];
        
        for (User agent : agents) {
            if (String.isNotBlank(agent.Skills__c)) {
                List<String> skills = agent.Skills__c.split(';');
                for (String skill : skills) {
                    skill = skill.trim();
                    if (!agentsBySkill.containsKey(skill)) {
                        agentsBySkill.put(skill, new List<User>());
                    }
                    agentsBySkill.get(skill).add(agent);
                }
            } else {
                // Default to general support
                if (!agentsBySkill.containsKey('General')) {
                    agentsBySkill.put('General', new List<User>());
                }
                agentsBySkill.get('General').add(agent);
            }
        }
        
        return agentsBySkill;
    }
    
    /**
     * @description Gets current workload for each agent
     * @param agents List of agents to check
     * @return Map of agent ID to case count
     */
    private static Map<Id, Integer> getCurrentWorkload(List<User> agents) {
        Map<Id, Integer> workloadMap = new Map<Id, Integer>();
        Set<Id> agentIds = new Set<Id>();
        
        for (User agent : agents) {
            agentIds.add(agent.Id);
            workloadMap.put(agent.Id, 0);
        }
        
        // Count open cases for each agent
        AggregateResult[] results = [
            SELECT OwnerId, COUNT(Id) caseCount
            FROM Case 
            WHERE OwnerId IN :agentIds 
            AND IsClosed = false
            GROUP BY OwnerId
        ];
        
        for (AggregateResult result : results) {
            Id ownerId = (Id) result.get('OwnerId');
            Integer count = (Integer) result.get('caseCount');
            workloadMap.put(ownerId, count);
        }
        
        return workloadMap;
    }
    
    /**
     * @description Checks if the given ID is a queue
     * @param ownerId The owner ID to check
     * @return True if it's a queue, false otherwise
     */
    private static Boolean isQueue(Id ownerId) {
        String ownerIdString = String.valueOf(ownerId);
        return ownerIdString.startsWith('00G'); // Queue IDs start with 00G
    }
    
    /**
     * @description Creates an assignment log entry for audit purposes
     * @param caseRecord The assigned case
     * @param agent The assigned agent
     */
    private static void createAssignmentLog(Case caseRecord, User agent) {
        try {
            Assignment_Log__c log = new Assignment_Log__c(
                Case__c = caseRecord.Id,
                Assigned_Agent__c = agent.Id,
                Assignment_Date__c = DateTime.now(),
                Assignment_Reason__c = 'Skill-based automatic assignment',
                Case_Priority__c = caseRecord.Priority,
                Case_Type__c = caseRecord.Type
            );
            
            insert log;
        } catch (Exception e) {
            System.debug(LoggingLevel.WARN, 'Failed to create assignment log: ' + e.getMessage());
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

