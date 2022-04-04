codeunit 70102 "PTE Test Adjust Cost"
{
    Subtype = Test;

    [Test]
    procedure TestAdjustCost()
    var
        Item: Record Item;
        PurchHdr: Record "Purchase Header";
        ItemAdjustCostLogEntry: Record "PTE Item Adjust Cost Log Entry";
        Library: Codeunit "PTE Test Library";
    begin
        // Given
        Library.CreateItemWithUnitPriceAndUnitCost(Item, 20, 10);
        Library.CreatePurchaseDocumentWithItem(PurchHdr, '10000', Item."No.", 25, '', 0D);
        Library.PostPurchaseDocument(PurchHdr, true, true);
        Item.Get(Item."No.");

        // When
        ItemAdjustCostLogEntry.SetRange("Item No.", Item."No.");
        ItemAdjustCostLogEntry.SetRange(Processed, false);

        // Then
        ItemAdjustCostLogEntry.FindFirst();

    end;

    [Test]
    procedure TestAdjustCostRun()
    var
        Item: Record Item;
        PurchHdr: Record "Purchase Header";
        ItemAdjustCostLogEntry: Record "PTE Item Adjust Cost Log Entry";
        RunAdjustCost: Codeunit "PTE Run Item Adjust Cost";
        Library: Codeunit "PTE Test Library";
    begin
        // Given
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

    end;


}