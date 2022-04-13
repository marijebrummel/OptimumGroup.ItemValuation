codeunit 62027 "PTE Run Item Adjust Cost"
{
    trigger OnRun()
    var
        Items: List of [Code[20]];
    begin
        Items := CreateBuffer();
        ProcessBuffer(Items);
        SetBufferProcessed(Items);
        RunPostCostToGL;
    end;

    local procedure RunPostCostToGL()
    var
        PostInventoryCostToGL: Codeunit "Post Inventory Cost to G/L";
    begin
        PostInventoryCostToGL.Run();
    end;

    local procedure CreateBuffer() Items: List of [Code[20]];
    var
        ItemAdjustCostLogEntry: Record "PTE Item Adjust Cost Log Entry";
    begin
        ItemAdjustCostLogEntry.SetCurrentKey(Processed);
        ItemAdjustCostLogEntry.SetRange(Processed, false);
        if ItemAdjustCostLogEntry.IsEmpty then
            exit;
        ItemAdjustCostLogEntry.FindSet();
        repeat
            if not Items.Contains(ItemAdjustCostLogEntry."Item No.") then   // For safety... each item should only have one record...
                Items.Add(ItemAdjustCostLogEntry."Item No.");
        until ItemAdjustCostLogEntry.Next() = 0;
    end;

    local procedure ProcessBuffer(Items: List of [Code[20]])
    var
        Item: Record Item;
        Value: Code[20];
    begin
        foreach Value in Items do begin
            Item.Get(Value);
            MakeAdjustment(Item);
        end;
    end;

    local procedure MakeAdjustment(Item: Record Item)
    var
        InvAdjmnt: Codeunit "Inventory Adjustment";
    begin
        Item.SetRecFilter();
        InvAdjmnt.SetFilterItem(Item);
        InvAdjmnt.MakeMultiLevelAdjmt();
    end;

    local procedure SetBufferProcessed(Items: List of [Code[20]])
    var
        ItemAdjustCostLogEntry: Record "PTE Item Adjust Cost Log Entry";
        Value: Code[20];
    begin
        ItemAdjustCostLogEntry.LockTable();
        foreach Value in Items do begin
            ItemAdjustCostLogEntry.SetRange("Item No.", Value);
            ItemAdjustCostLogEntry.SetRange(Processed, false);
            ItemAdjustCostLogEntry.ModifyAll(Processed, true);
        end;
    end;

}