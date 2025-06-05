# Contributing to Automated Case Assignment & Escalation System

Thank you for your interest in contributing to our Salesforce case management solution! We welcome contributions from the community and are grateful for your help in making this project better.

## Getting Started

### Prerequisites
- Salesforce Developer Edition org or Playground
- Salesforce CLI installed
- VS Code with Salesforce Extension Pack
- Git for version control
- Basic knowledge of Apex, Lightning Web Components, and Salesforce configuration

### Setting Up Your Development Environment

1. **Fork the Repository**
   ```bash
   git clone https://github.com/Riddhigangwal/Automated-Case-Assignment-Escalation-System.git
   cd automated-case-assignment-escalation
   ```

2. **Create a Scratch Org**
   ```bash
   sfdx force:org:create -f config/project-scratch-def.json -a CaseAssignmentDev
   sfdx force:config:set defaultusername=CaseAssignmentDev
   ```

3. **Deploy the Code**
   ```bash
   sfdx force:source:push
   sfdx force:user:permset:assign -n Case_Assignment_Admin
   ```

4. **Import Sample Data**
   ```bash
   sfdx force:data:tree:import -p scripts/sample-data/data-plan.json
   ```

## How to Contribute

### Reporting Bugs
Before submitting a bug report:
- Check if the issue already exists in our [GitHub Issues](https://github.com/Riddhigangwal/automated-case-assignment-escalation/issues)
- Ensure you're using the latest version
- Test the issue in a fresh scratch org

When reporting bugs, please include:
- Clear description of the issue
- Steps to reproduce
- Expected vs actual behavior
- Salesforce org edition and API version
- Screenshots if applicable
- Debug logs if relevant

### Suggesting Features
We welcome feature suggestions! Please:
- Check existing feature requests first
- Provide detailed description of the proposed feature
- Explain the business value and use cases
- Consider backward compatibility

### Code Contributions

#### Branch Naming Convention
- `feature/description-of-feature`
- `bugfix/description-of-fix`
- `hotfix/critical-fix-description`
- `refactor/description-of-refactor`

#### Pull Request Process

1. **Create a Feature Branch**
   ```bash
   git checkout -b feature/new-assignment-algorithm
   ```

2. **Make Your Changes**
   - Follow our coding standards (see below)
   - Include comprehensive test coverage
   - Update documentation as needed

3. **Test Your Changes**
   ```bash
   # Run all tests
   sfdx force:apex:test:run --testlevel RunLocalTests
   
   # Check code coverage
   sfdx force:apex:test:run --classnames YourTestClass --codecoverage
   ```

4. **Commit Your Changes**
   ```bash
   git add .
   git commit -m "feat: add new assignment algorithm for VIP customers"
   ```

5. **Push and Create Pull Request**
   ```bash
   git push origin feature/new-assignment-algorithm
   ```

#### Commit Message Guidelines
We follow the [Conventional Commits](https://www.conventionalcommits.org/) specification:

- `feat:` New feature
- `fix:` Bug fix
- `docs:` Documentation changes
- `style:` Code style changes (formatting, etc.)
- `refactor:` Code refactoring
- `test:` Adding or updating tests
- `chore:` Maintenance tasks

Examples:
```
feat: add skill-based case routing for technical cases
fix: resolve null pointer exception in escalation handler
docs: update README with new configuration options
test: add unit tests for case assignment logic
```

## Coding Standards

### Apex Guidelines

1. **Naming Conventions**
   - Classes: PascalCase (`CaseAssignmentHandler`)
   - Methods: camelCase (`assignCasesToAgents`)
   - Variables: camelCase (`availableAgents`)
   - Constants: UPPER_SNAKE_CASE (`MAX_CASES_PER_AGENT`)

2. **Class Structure**
   ```apex
   /**
    * @description Brief description of the class
    * @author Your Name
    * @date YYYY-MM-DD
    * @version X.X.X
    */
   public with sharing class YourClassName {
       // Constants first
       private static final String CONSTANT_VALUE = 'value';
       
       // Instance variables
       private String instanceVariable;
       
       // Public methods
       public void publicMethod() {
           // Implementation
       }
       
       // Private methods
       private void privateMethod() {
           // Implementation
       }
   }
   ```

3. **Method Documentation**
   ```apex
   /**
    * @description Assigns cases to appropriate agents based on skills and workload
    * @param cases List of cases to assign
    * @param assignmentCriteria Criteria for assignment logic
    * @return Map of case IDs to assigned user IDs
    * @throws CustomException When no suitable agent is found
    */
   public Map<Id, Id> assignCases(List<Case> cases, AssignmentCriteria assignmentCriteria) {
       // Implementation
   }
   ```

4. **Error Handling**
   ```apex
   try {
       // Business logic
   } catch (DmlException e) {
       System.debug(LoggingLevel.ERROR, 'DML Error: ' + e.getMessage());
       // Log to custom error object
       ErrorLogger.logError('ClassName.methodName', e.getMessage(), e.getStackTraceString());
       throw new CustomException('User-friendly error message');
   }
   ```

5. **SOQL Best Practices**
   ```apex
   // Good: Bulkified query with selective fields
   List<Case> cases = [
       SELECT Id, Priority, Type, OwnerId, Account.Name
       FROM Case 
       WHERE Id IN :caseIds 
       AND IsClosed = false
       LIMIT 200
   ];
   
   // Avoid: Queries in loops
   for (Case c : cases) {
       List<User> agents = [SELECT Id FROM User WHERE Skills__c INCLUDES (:c.Type)];
   }
   ```

### Lightning Web Components

1. **File Structure**
   ```
   componentName/
   ├── componentName.html
   ├── componentName.js
   ├── componentName.css
   ├── componentName.js-meta.xml
   └── __tests__/
       └── componentName.test.js
   ```

2. **JavaScript Standards**
   ```javascript
   import { LightningElement, api, track } from 'lwc';
   
   export default class ComponentName extends LightningElement {
       @api recordId;
       @track cases = [];
       
       // Lifecycle hooks
       connectedCallback() {
           this.loadCases();
       }
       
       // Event handlers
       handleCaseSelection(event) {
           // Implementation
       }
       
       // Private methods
       loadCases() {
           // Implementation
       }
   }
   ```

### Testing Standards

1. **Test Coverage Requirements**
   - Minimum 90% code coverage for all Apex classes
   - All public methods must have test coverage
   - Test both positive and negative scenarios
   - Include bulk testing (200 records)

2. **Test Class Structure**
   ```apex
   @isTest
   private class CaseAssignmentHandlerTest {
       
       @TestSetup
       static void setupTestData() {
           // Create test data used by multiple test methods
       }
       
       @isTest
       static void testSuccessfulAssignment() {
           // Test successful case assignment
           Test.startTest();
           // Call method under test
           Test.stopTest();
           
           // Assertions
           Assert.areEqual(expected, actual, 'Error message');
       }
       
       @isTest
       static void testBulkAssignment() {
           // Test with 200 records
       }
       
       @isTest
       static void testExceptionHandling() {
           // Test error scenarios
       }
   }
   ```

3. **LWC Testing**
   ```javascript
   import { createElement } from 'lwc';
   import ComponentName from 'c/componentName';
   
   describe('c-component-name', () => {
       afterEach(() => {
           while (document.body.firstChild) {
               document.body.removeChild(document.body.firstChild);
           }
       });
       
       it('should render correctly', () => {
           const element = createElement('c-component-name', {
               is: ComponentName
           });
           document.body.appendChild(element);
           
           expect(element).toBeTruthy();
       });
   });
   ```

## Documentation

### Code Comments
- Use clear, concise comments
- Explain "why" not "what"
- Update comments when code changes
- Use JSDoc format for method documentation

### README Updates
When adding new features:
- Update the feature list
- Add configuration instructions
- Include usage examples
- Update troubleshooting section if needed

## Review Process

### Code Review Checklist
- [ ] Code follows established patterns and standards
- [ ] All tests pass and coverage meets requirements
- [ ] Documentation is updated
- [ ] No sensitive information is exposed
- [ ] Performance implications are considered
- [ ] Backward compatibility is maintained
- [ ] Security best practices are followed

### Review Timeline
- Initial review within 48 hours
- Final approval within 1 week
- Critical fixes reviewed within 24 hours

## Community Guidelines

### Code of Conduct
- Be respectful and inclusive
- Focus on constructive feedback
- Help newcomers learn
- Celebrate diverse perspectives

### Communication Channels
- GitHub Issues for bug reports and feature requests
- Pull Request comments for code discussions
- Email for security-related issues

## Getting Help

If you need assistance:
1. Check the documentation and README
2. Search existing GitHub issues
3. Join our community discussions
4. Contact the maintainers

## Recognition

We appreciate all contributions! Contributors will be:
- Listed in the CONTRIBUTORS.md file
- Mentioned in release notes
- Invited to join our contributor Slack channel

Thank you for helping make the Automated Case Assignment & Escalation System better for everyone! 🎉

