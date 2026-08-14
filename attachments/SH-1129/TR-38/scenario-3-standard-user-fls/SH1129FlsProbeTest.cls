/**
 * SH-1129 / PR #2541 — Scenario 3 of the QA plan in SH-1179.
 *
 * Proves that a NON-ADMIN user holding only the Veevart permission set can still insert
 * Auctifera__Inventory_History__c now that Auctifera__Item_per_location__c is an optional
 * lookup. Removing required=true drops the implicit field-level-security grant Salesforce
 * gives required fields, which is why PR #2541 had to add an explicit <fieldPermissions>
 * entry to the Veevart permission set. CI caught the gap as:
 *   System.UnexpectedException: Insufficient access on
 *   Auctifera__Inventory_History__c field Auctifera__Item_per_location__c
 *
 * This has to be a test class rather than anonymous Apex: System.runAs is only available in
 * test context, and no non-admin user in UAT carries the Veevart permission set, so there is
 * no existing account to execute as. The probe user is created inside the test and never
 * persists — Apex tests always roll back, including SeeAllData tests.
 *
 * The probe creates its own parent records, because AccessLevel.USER_MODE enforces record-level
 * sharing as well as FLS: parents owned by the admin fail with
 * INSUFFICIENT_ACCESS_ON_CROSS_REFERENCE_ENTITY, which is a harness artifact and not the thing
 * under test. Ownership removes that confound so a USER_MODE failure can only mean CRUD/FLS.
 *
 * Every sub-result is captured independently rather than aborting on the first problem, so a
 * setup failure can be told apart from a genuine FLS failure.
 *
 * TEMPORARY: deploy, run, then delete. Not intended to live in the product repo.
 */
@IsTest(SeeAllData=true)
private class SH1129FlsProbeTest {
    @IsTest
    static void standardUserWithVeevartPermsetInsertsInventoryHistory() {
        Profile standardProfile = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        PermissionSet veevart = [SELECT Id FROM PermissionSet WHERE Name = 'Veevart' LIMIT 1];
        List<PackageLicense> auctifera = [SELECT Id FROM PackageLicense WHERE NamespacePrefix = 'Auctifera' LIMIT 1];

        User probe = new User(
            FirstName = 'SH1129',
            LastName = 'FLS Probe',
            Alias = 'sh1129p',
            Email = 'sh1129.fls.probe@example.invalid',
            Username = 'sh1129.fls.probe.' + String.valueOf(DateTime.now().getTime()) + '@veevartmuseumdemo.uat.invalid',
            ProfileId = standardProfile.Id,
            TimeZoneSidKey = 'America/Bogota',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US'
        );

        // Setup-object DML must be isolated from data DML or the transaction hits MIXED_DML_OPERATION.
        System.runAs(new User(Id = UserInfo.getUserId())) {
            insert probe;
            insert new PermissionSetAssignment(AssigneeId = probe.Id, PermissionSetId = veevart.Id);
            // Auctifera is licensed per user (PackageLicense.UsedLicenses > 0). Without this the probe
            // would fail for a missing package license, which would look like an FLS failure.
            if (!auctifera.isEmpty()) {
                insert new UserPackageLicense(UserId = probe.Id, PackageLicenseId = auctifera[0].Id);
            }
        }

        // A Store location is reused rather than created: the lookup filter demands Type__c = 'Store'
        // and this org's validation rule rejects new Store locations without the enhanced-locations
        // feature. Read-only reference, nothing is written to it.
        Auctifera__Display_Storage_Location__c loc = [
            SELECT Id FROM Auctifera__Display_Storage_Location__c WHERE Auctifera__Type__c = 'Store' LIMIT 1
        ];

        Boolean objectCreateable = false;
        Boolean fieldCreateable = false;
        Boolean fieldAccessible = false;
        Boolean fieldSurvivesStrip = false;
        Boolean parentsCreated = false;
        Boolean inserted = false;
        Boolean lookupPersisted = false;
        String setupFailure = '';
        String insertFailure = '';

        System.runAs(probe) {
            // FLS as seen by the probe user. This is the exact grant PR #2541 added.
            Schema.DescribeSObjectResult ihDescribe = Auctifera__Inventory_History__c.SObjectType.getDescribe();
            Schema.DescribeFieldResult iplField =
                Auctifera__Inventory_History__c.Auctifera__Item_per_location__c.getDescribe();
            objectCreateable = ihDescribe.isCreateable();
            fieldCreateable = iplField.isCreateable();
            fieldAccessible = iplField.isAccessible();

            Auctifera__Item_per_location__c ipl;
            try {
                Auctifera__CatalogItem__c item = new Auctifera__CatalogItem__c(
                    Name = 'SH-1129 FLS Probe Item',
                    Auctifera__Price__c = 25,
                    Auctifera__Product_ID__c = 'SH1129-FLS-' + String.valueOf(DateTime.now().getTime()),
                    Auctifera__Bypass_Stock__c = true
                );
                insert item;

                ipl = new Auctifera__Item_per_location__c(
                    Auctifera__Shop_Item__c = item.Id,
                    Auctifera__Display_Storage_Location__c = loc.Id
                );
                insert ipl;
                parentsCreated = true;
            } catch (Exception e) {
                setupFailure = e.getTypeName() + ': ' + e.getMessage();
            }

            if (parentsCreated) {
                Auctifera__Inventory_History__c history = new Auctifera__Inventory_History__c(
                    Auctifera__Shop_Item__c = ipl.Auctifera__Shop_Item__c,
                    Auctifera__Location__c = loc.Id,
                    Auctifera__Item_per_location__c = ipl.Id,
                    Auctifera__Date__c = Date.today(),
                    Auctifera__Total_Stock__c = 4,
                    Auctifera__Item_Cost__c = 25
                );

                // FLS-only check: stripInaccessible drops fields the user cannot create, ignoring
                // sharing. If the permission-set grant were missing, the lookup would be removed here.
                SObjectAccessDecision decision = Security.stripInaccessible(
                    AccessType.CREATABLE,
                    new List<SObject>{ history }
                );
                Set<String> removed = decision.getRemovedFields().get('Auctifera__Inventory_History__c');
                fieldSurvivesStrip = (removed == null || !removed.contains('Auctifera__Item_per_location__c'));

                try {
                    Database.insert(history, AccessLevel.USER_MODE);
                    inserted = true;
                    // Bind a plain variable: dynamic SOQL does not accept expression binds like :history.Id.
                    Id historyId = history.Id;
                    List<Auctifera__Inventory_History__c> stored = Database.query(
                        'SELECT Id, Auctifera__Item_per_location__c FROM Auctifera__Inventory_History__c WHERE Id = :historyId',
                        AccessLevel.USER_MODE
                    );
                    lookupPersisted = !stored.isEmpty() && stored[0].Auctifera__Item_per_location__c == ipl.Id;
                } catch (Exception e) {
                    insertFailure = e.getTypeName() + ': ' + e.getMessage();
                }
            }
        }

        System.debug(LoggingLevel.INFO, '======================================================');
        System.debug(LoggingLevel.INFO, '  SCENARIO 3 (TC-69) - standard user + Veevart permset');
        System.debug(LoggingLevel.INFO, '  probe profile = Standard User, package license granted = ' + !auctifera.isEmpty());
        System.debug(LoggingLevel.INFO, '  Inventory_History__c createable by probe = ' + objectCreateable + ' (want true)');
        System.debug(LoggingLevel.INFO, '  Item_per_location__c createable = ' + fieldCreateable + ' (want true)');
        System.debug(LoggingLevel.INFO, '  Item_per_location__c accessible = ' + fieldAccessible + ' (want true)');
        System.debug(LoggingLevel.INFO, '  survives stripInaccessible(CREATABLE) = ' + fieldSurvivesStrip + ' (want true)');
        System.debug(LoggingLevel.INFO, '  parent records created by probe = ' + parentsCreated + (setupFailure == '' ? '' : ' | ' + setupFailure));
        System.debug(LoggingLevel.INFO, '  USER_MODE insert succeeded = ' + inserted + (insertFailure == '' ? '' : ' | ' + insertFailure));
        System.debug(LoggingLevel.INFO, '  lookup written and readable = ' + lookupPersisted + ' (want true)');
        System.debug(LoggingLevel.INFO, '  RESULT: ' + ((fieldCreateable && fieldAccessible && fieldSurvivesStrip && inserted && lookupPersisted) ? 'PASS' : 'FAIL'));
        System.debug(LoggingLevel.INFO, '======================================================');

        Assert.isTrue(objectCreateable, 'Probe must have create access on Inventory_History__c via the Veevart permission set.');
        Assert.isTrue(fieldCreateable, 'Item_per_location__c must be createable by the probe — this is the grant PR #2541 added.');
        Assert.isTrue(fieldAccessible, 'Item_per_location__c must be readable by the probe.');
        Assert.isTrue(fieldSurvivesStrip, 'Item_per_location__c must survive stripInaccessible(CREATABLE); being removed means FLS is missing.');
        Assert.isTrue(parentsCreated, 'Probe could not create the parent records. Setup failure: ' + setupFailure);
        Assert.isTrue(inserted, 'Probe must be able to insert Inventory History in USER_MODE. Failure: ' + insertFailure);
        Assert.isTrue(lookupPersisted, 'Item_per_location__c must persist and be readable, not stripped by FLS.');
    }
}
