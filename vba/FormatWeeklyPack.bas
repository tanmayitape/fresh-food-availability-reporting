Attribute VB_Name = "FormatWeeklyPack"
Option Explicit

' Formats the workbook written by weekly_pack.py into a readable MI pack.
' In Excel: Alt+F11 > File > Import File > this .bas, then run FormatWeeklyPack with the pack open.

Private Const TARGET As Double = 0.8  ' availability below this is highlighted

Public Sub FormatWeeklyPack()
    Dim ws As Worksheet
    Application.ScreenUpdating = False
    For Each ws In ActiveWorkbook.Worksheets
        FormatSheet ws
    Next ws
    ActiveWorkbook.Worksheets(1).Activate
    Application.ScreenUpdating = True
    MsgBox "Pack formatted: " & ActiveWorkbook.Worksheets.Count & " sheets.", vbInformation
End Sub

Private Sub FormatSheet(ws As Worksheet)
    Dim lastRow As Long, lastCol As Long, c As Long, header As String
    Dim body As Range

    If ws.Range("A1").Value = ws.Name Then Exit Sub   ' already formatted
    lastRow = ws.Cells(ws.Rows.Count, 1).End(xlUp).Row
    lastCol = ws.Cells(1, ws.Columns.Count).End(xlToLeft).Column

    ' Title rows above the table
    ws.Rows("1:2").Insert
    ws.Range("A1").Value = ws.Name
    ws.Range("A1").Font.Size = 14
    ws.Range("A1").Font.Bold = True
    lastRow = lastRow + 2

    ' Header row
    With ws.Range(ws.Cells(3, 1), ws.Cells(3, lastCol))
        .Font.Bold = True
        .Font.Color = vbWhite
        .Interior.Color = RGB(31, 78, 121)
        .Replace What:="_", Replacement:=" "
    End With

    If lastRow > 3 Then
        For c = 1 To lastCol
            header = LCase$(ws.Cells(3, c).Value)
            Set body = ws.Range(ws.Cells(4, c), ws.Cells(lastRow, c))
            If header = "availability" Or header = "share on promo" Then
                body.NumberFormat = "0.0%"
                If header = "availability" Then HighlightBelowTarget body
            ElseIf header = "week start" Then
                body.NumberFormat = "dd mmm yyyy"
            ElseIf header = "run at" Then
                body.NumberFormat = "dd mmm yyyy hh:mm"
            ElseIf InStr(header, "units") > 0 Or header = "rows failed" Or InStr(header, "days") > 0 Then
                body.NumberFormat = "#,##0"
            End If
        Next c
        ws.Range(ws.Cells(3, 1), ws.Cells(lastRow, lastCol)).AutoFilter
    End If

    ws.Columns.AutoFit
    ws.Activate
    ActiveWindow.FreezePanes = False
    ws.Range("A4").Select
    ActiveWindow.FreezePanes = True
End Sub

Private Sub HighlightBelowTarget(rng As Range)
    rng.FormatConditions.Delete
    With rng.FormatConditions.Add(Type:=xlCellValue, Operator:=xlLess, Formula1:="=" & TARGET)
        .Interior.Color = RGB(248, 203, 173)
        .Font.Color = RGB(156, 0, 6)
    End With
End Sub
