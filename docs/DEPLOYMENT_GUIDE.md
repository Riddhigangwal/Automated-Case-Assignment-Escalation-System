# Deployment Guide - Automated Case Assignment & Escalation System

This guide will walk you through deploying the Automated Case Assignment & Escalation System to your Salesforce org.

## Prerequisites

### System Requirements
- Salesforce org with System Administrator access
- API access enabled
- Service Cloud license (recommended for advanced case management features)
- Knowledge Base enabled (optional, for knowledge article integration)

### Tools Required
- **Salesforce CLI** (for command-line deployment)
- **VS Code with Salesforce Extension Pack** (for IDE deployment)
- **Git** (for version control)

## Pre-Deployment Checklist

### 1. Backup Your Org
```bash
# Export existing case assignment rules
sfdx force:data:soql:query -q "SELECT Id, Name, SobjectType FROM AssignmentRule WHERE SobjectType = 'Case'"

# Export current case data
sfdx force:data:tree:export -q "SELECT Id, CaseNumber, Subject, Priority, Status, OwnerId FROM Case LIMIT 100" -d ./backup
```

### 2. Review Current Configuration
- Document existing case assignment rules
- Note current escalation rules and business hours
- List active workflow rules and process builders
- Review existing triggers on Case object

### 3. Environment Preparation
```bash
# Verify Salesforce CLI installation
sfdx --version

# Authenticate to your org
sfdx force:auth:web:login -a ProductionOrg
```

## Deployment Methods

### Method 1: Salesforce CLI Deployment (Recommended)

#### Step 1: Clone the Repository
```bash
git clone https://github.com/yourusername/automated-case-assignment-escalation.git
cd automated-case-assignment-escalation
```

#### Step 2: Validate Deployment
```bash
# Check deployment validity without deploying
sfdx force:source:deploy -p force-app/main/default -c -l RunLocalTests
```

#### Step 3: Deploy to Sandbox First
```bash
# Deploy to sandbox for testing
sfdx force:auth:web:login -a SandboxOrg
sfdx force:source:deploy -p force-app/main/default -l RunLocalTests
```

#### Step 4: Run Tests
```bash
# Run all tests
sfdx force:apex:test:run --testlevel RunLocalTests --outputdir ./test-results --resultformat junit

# Check test coverage
sfdx force:apex:test:run --testlevel RunLocalTests --codecoverage
```

#### Step 5: Deploy to Production
```bash
# Deploy to production (only after successful sandbox testing)
sfdx force:source:deploy -p force-app/main/default -l RunLocalTests --checkonly

# If validation passes, deploy for real
sfdx force:source:deploy -p force-app/main/default -l RunLocalTests
```

### Method 2: VS Code Deployment

#### Step 1: Open Project in VS Code
1. Open VS Code
2. Install Salesforce Extension Pack
3. Open the project folder
4. Press `Ctrl+Shift+P` and run "SFDX: Authorize an Org"

#### Step 2: Deploy Components
1. Right-click on `force-app` folder
2. Select "SFDX: Deploy Source to Org"
3. Monitor deployment progress in VS Code output

### Method 3: Change Sets (Alternative)

#### Step 1: Create Outbound Change Set
1. Go to Setup → Deploy → Outbound Change Sets
2. Create new change set: "Case Assignment System v2.1"
3. Add components:
   - Apex Classes: CaseAssignmentHandler, EscalationService, CaseTriggerHandler
   - Apex Triggers: CaseTrigger
   - Custom Fields (see configuration section)
   - Permission Sets

#### Step 2: Upload and Deploy
1. Upload change set
2. In target org: Setup → Deploy → Inbound Change Sets
3. Deploy with "Run All Tests" option

## Post-Deployment Configuration

### 1. Custom Fields Setup

Add these custom fields to the Case object:

```sql
-- Required Custom Fields for Case Object
Assignment_Date__c (DateTime)
Assignment_Method__c (Text, 50)
Escalation_Level__c (Picklist: Level 0, Level 1, Level 2, Level 3)
Escalation_Date__c (DateTime)
Escalation_Reason__c (Text Area, 255)
SLA_Start_Time__c (DateTime)
Response_SLA_Target__c (DateTime)
Resolution_SLA_Target__c (DateTime)
First_Response_Time__c (DateTime)
Resolution_Time__c (DateTime)
Last_Owner_Change__c (DateTime)
Previous_Owner__c (Lookup to User)
Business_Impact__c (Picklist: Low, Medium, High, Critical)
Product__c (Text, 100)
```

### 2. User Object Custom Fields

Add these custom fields to the User object:

```sql
-- Required Custom Fields for User Object
Skills__c (Multi-select Picklist: Technical;Billing;General;API;Integration)
Experience_Level__c (Picklist: Junior, Senior, Expert)
Max_Cases__c (Number, 18, 0, Default: 20)
Available_for_Assignment__c (Checkbox, Default: True)
Available_for_Escalation__c (Checkbox, Default: False)
Role__c (Picklist: Agent, Team Lead, Manager, Director)
Current_Escalated_Cases__c (Number, 18, 0, Default: 0)
```

### 3. Create Custom Objects

#### Assignment Log Object
```xml
<!-- Assignment_Log__c custom object -->
Object Name: Assignment Log
API Name: Assignment_Log__c
Fields:
- Case__c (Master-Detail to Case)
- Assigned_Agent__c (Lookup to User)
- Assignment_Date__c (DateTime)
- Assignment_Reason__c (Text Area, 255)
- Case_Priority__c (Text, 50)
- Case_Type__c (Text, 50)
```

#### Escalation Log Object
```xml
<!-- Escalation_Log__c custom object -->
Object Name: Escalation Log
API Name: Escalation_Log__c
Fields:
- Case__c (Master-Detail to Case)
- Escalated_To__c (Lookup to User)
- Escalation_Date__c (DateTime)
- Escalation_Level__c (Text, 50)
- Escalation_Reason__c (Text Area, 255)
- Case_Priority__c (Text, 50)
- Original_Owner__c (Lookup to User)
```

#### Error Log Object
```xml
<!-- Error_Log__c custom object -->
Object Name: Error Log
API Name: Error_Log__c
Fields:
- Class_Name__c (Text, 100)
- Error_Message__c (Text Area, 1000)
- Stack_Trace__c (Long Text Area, 5000)
- Error_Date__c (DateTime)
- User__c (Lookup to User)
```

### 4. Configure Assignment Rules

#### Disable Existing Rules
1. Go to Setup → Case Assignment Rules
2. Deactivate existing assignment rules
3. Document the rules for rollback if needed

#### Create New Assignment Rule
```sql
-- Example assignment rule entry
Rule Name: Automated Skill-Based Assignment
Active: True
Criteria: 
- Case: Created Date NOT EQUAL TO null
Assignment: Use Apex class assignment (handled by trigger)
```

### 5. Set Up Business Hours

1. Go to Setup → Business Hours
2. Create business hours for different regions
3. Set as default for escalation calculations

### 6. Configure Email Templates

#### Create Escalation Notification Template
```html
<!-- Case_Escalation_Notification email template -->
Name: Case Escalation Notification
DeveloperName: Case_Escalation_Notification
Subject: URGENT: Case {!Case.CaseNumber} Escalated to You
Body:
Dear {!User.FirstName},

Case {!Case.CaseNumber} has been escalated to you.

Case Details:
- Subject: {!Case.Subject}
- Priority: {!Case.Priority}
- Customer: {!Case.Account.Name}
- Original Owner: {!Case.Previous_Owner__c}
- Escalation Reason: {!Case.Escalation_Reason__c}

Please review and take action immediately.

Best regards,
Case Management System
```

### 7. Permission Sets

#### Create Case Assignment Admin Permission Set
```sql
Permission Set: Case_Assignment_Admin
Object Permissions:
- Case: Read, Create, Edit, Delete, View All, Modify All
- Assignment_Log__c: Read, Create, Edit, Delete, View All, Modify All
- Escalation_Log__c: Read, Create, Edit, Delete, View All, Modify All
- Error_Log__c: Read, Create, Edit, Delete, View All, Modify All
- User: Read, Edit (for assignment fields)

Apex Class Access:
- CaseAssignmentHandler
- EscalationService
- CaseTriggerHandler
```

#### Assign Permission Sets
```bash
# Assign to administrators
sfdx force:user:permset:assign -n Case_Assignment_Admin -u admin@company.com

# Assign to support managers
sfdx force:user:permset:assign -n Case_Assignment_Manager -u manager@company.com
```

### 8. User Setup

#### Configure Support Agents
1. Update User records with:
   - Skills__c (e.g., "Technical;API")
   - Experience_Level__c (Junior/Senior/Expert)
   - Available_for_Assignment__c = true
   - Max_Cases__c (recommended: 15-25)

#### Configure Managers
1. Update User records with:
   - Role__c = "Manager" or "Team Lead"
   - Available_for_Escalation__c = true

### 9. Testing and Validation

#### Create Test Cases
```apex
// Test case creation script
List<Case> testCases = new List<Case>{
    new Case(
        Subject = 'API Integration Issue',
        Priority = 'High',
        Type = 'Technical',
        Description = 'Customer having trouble with API integration'
    ),
    new Case(
        Subject = 'Billing Question',
        Priority = 'Medium', 
        Type = 'Billing',
        Description = 'Question about invoice charges'
    )
};
insert testCases;
```

#### Verify Assignments
1. Create test cases with different priorities and types
2. Verify automatic assignment to appropriate agents
3. Test escalation workflows
4. Check email notifications

#### Performance Testing
```apex
// Bulk test - create 100 cases
List<Case> bulkCases = new List<Case>();
for(Integer i = 0; i < 100; i++) {
    bulkCases.add(new Case(
        Subject = 'Test Case ' + i,
        Priority = 'Medium',
        Type = 'General'
    ));
}
insert bulkCases;
```

## Scheduled Jobs Setup

### 1. Create Escalation Job
```apex
// Schedule escalation job to run every hour
System.schedule('Case Escalation Check', '0 0 * * * ?', new EscalationScheduler());
```

### 2. Create EscalationScheduler Class
```apex
public class EscalationScheduler implements Schedulable {
    public void execute(SchedulableContext sc) {
        EscalationService.batchProcessEscalations();
    }
}
```

## Monitoring and Maintenance

### 1. Set Up Dashboards

Create dashboards to monitor:
- Case assignment distribution
- Escalation rates
- SLA compliance
- Agent workload
- System errors

### 2. Regular Maintenance Tasks

#### Weekly
- Review error logs
- Check assignment distribution
- Validate escalation patterns

#### Monthly
- Update agent skills and capacity
- Review and adjust assignment rules
- Analyze performance metrics

#### Quarterly
- Review and update business rules
- Optimize assignment algorithms
- Update documentation

## Rollback Plan

If issues arise, follow this rollback procedure:

### 1. Immediate Rollback
```bash
# Deactivate triggers
sfdx force:source:deploy -m "ApexTrigger:CaseTrigger" --postdestructivechanges destructiveChanges.xml

# Reactivate old assignment rules
# (Manual step in Setup)
```

### 2. Complete Rollback
```bash
# Remove all components
sfdx force:source:deploy --postdestructivechanges destructiveChanges.xml

# Restore from backup
sfdx force:data:tree:import -f backup/Case.json
```

## Troubleshooting

### Common Issues

#### Cases Not Being Assigned
**Solution:**
1. Check if users have correct skills configured
2. Verify Available_for_Assignment__c = true
3. Check assignment rule criteria
4. Review debug logs

#### Escalations Not Triggering
**Solution:**
1. Verify scheduled job is running
2. Check business hours configuration
3. Validate escalation rule criteria
4. Review email template configuration

#### Performance Issues
**Solution:**
1. Check governor limit usage
2. Review SOQL queries for optimization
3. Monitor batch job execution
4. Consider caching strategies

### Debug Commands
```bash
# Check scheduled jobs
sfdx force:data:soql:query -q "SELECT Id, JobName, State, NextFireTime FROM CronTrigger"

# View recent errors
sfdx force:data:soql:query -q "SELECT Class_Name__c, Error_Message__c, Error_Date__c FROM Error_Log__c ORDER BY Error_Date__c DESC LIMIT 10"

# Check assignment distribution
sfdx force:data:soql:query -q "SELECT OwnerId, COUNT(Id) FROM Case WHERE CreatedDate = TODAY GROUP BY OwnerId"
```

## Support

For deployment issues:
- Check the [GitHub Issues](https://github.com/yourusername/automated-case-assignment-escalation/issues)
- Review the [troubleshooting guide](TROUBLESHOOTING.md)
- Contact the development team

---

**Remember:** Always test in a sandbox environment before deploying to production!

