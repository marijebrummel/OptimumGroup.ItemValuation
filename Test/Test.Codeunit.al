codeunit 62029 "PTE Test Adjust Cost"
{
    Subtype = Test;
    [Test]
    procedure TestAdjustCost()
    var
        Item: Record Item;
        PurchHdr: Record "Purchase Header";
        ItemAdjustCostLogEntry: Record "PTE Item Adjust Cost Log Entry";
        PostValueEntryToGL: Record "Post Value Entry to G/L";
        Library: Codeunit "PTE Test Library";
        xNoOfValueEntriesToPostToGL: Integer;
    begin
        // Given
        MakeSureInventorySetupIsCorrect();
        xNoOfValueEntriesToPostToGL := PostValueEntryToGL.Count();
        Library.CreateItemWithUnitPriceAndUnitCost(Item, 20, 10);
        Library.CreatePurchaseDocumentWithItem(PurchHdr, '10000', Item."No.", 25, '', 0D);
        Library.PostPurchaseDocument(PurchHdr, true, true);
        Item.Get(Item."No.");

        // When
        ItemAdjustCostLogEntry.SetRange("Item No.", Item."No.");
        ItemAdjustCostLogEntry.SetRange(Processed, false);

        // Then
        ItemAdjustCostLogEntry.FindFirst();
        if xNoOfValueEntriesToPostToGL = PostValueEntryToGL.Count() then
            Error('Nothing has been prepared for the G/L');
    end;

    [Test]
    [HandlerFunctions('MessageHandler')]
    procedure TestAdjustCostRun()
    var
        Item: Record Item;
        PurchHdr: Record "Purchase Header";
        ItemAdjustCostLogEntry: Record "PTE Item Adjust Cost Log Entry";
        PostValueEntryToGL: Record "Post Value Entry to G/L";
        RunAdjustCost: Codeunit "PTE Run Item Adjust Cost";
        Library: Codeunit "PTE Test Library";
        xNoOfValueEntriesToPostToGL: Integer;
    begin
        // Given
        MakeSureInventorySetupIsCorrect();
        xNoOfValueEntriesToPostToGL := PostValueEntryToGL.Count();
        Library.CreateItemWithUnitPriceAndUnitCost(Item, 20, 10);
        Library.CreatePurchaseDocumentWithItem(PurchHdr, '10000', Item."No.", 25, '', 0D);
        Library.PostPurchaseDocument(PurchHdr, true, true);
        RunAdjustCost.Run();

        // When
        ItemAdjustCostLogEntry.SetRange("Item No.", Item."No.");
        ItemAdjustCostLogEntry.SetRange(Processed, true);

        // Then
        ItemAdjustCostLogEntry.FindFirst();
        Item.Get(Item."No.");
        Item.TestField("Cost is Adjusted", true);
        if xNoOfValueEntriesToPostToGL < PostValueEntryToGL.Count() then
            Error('Nothing has been posted to the G/L');

    end;

    local procedure MakeSureInventorySetupIsCorrect();
    var
        InventorySetup: Record "Inventory Setup";
    begin
        InventorySetup.LockTable();
        InventorySetup.Get();
        if InventorySetup."Automatic Cost Adjustment" <> InventorySetup."Automatic Cost Adjustment"::Never then
            InventorySetup.Validate("Automatic Cost Adjustment", InventorySetup."Automatic Cost Adjustment"::Never);
        if InventorySetup."Automatic Cost Posting" then
            InventorySetup.Validate("Automatic Cost Posting", false);
        if InventorySetup."Expected Cost Posting to G/L" = false then
            InventorySetup."Expected Cost Posting to G/L" := true;
        InventorySetup.Modify(true);
    end;

    [MessageHandler]
    procedure MessageHandler(Value: Text[1024])
    begin
    end;
}