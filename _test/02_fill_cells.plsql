declare

  workbook xlsx_writer.book_r;
  sheet    integer;

  xlsx     blob;

begin

  workbook := xlsx_writer.start_book;
  sheet    := xlsx_writer.add_sheet  (workbook, 'Name of the sheet');

  xlsx_writer.add_cell(workbook, sheet, 1, 1, text => 'foo'); 
  xlsx_writer.add_cell(workbook, sheet, 2, 2, text => 'bar'); 
  xlsx_writer.add_cell(workbook, sheet, 3, 3, text => 'baz'); 
  xlsx_writer.add_cell(workbook, sheet, 4, 4, text => '<&>'); -- Will it be replaced with correct entities?

  xlsx_writer.add_cell(workbook, sheet, 1, 4, value_ => 42   ); 
  xlsx_writer.add_cell(workbook, sheet, 2, 4, date_  => date '2015-08-28' + 13/17);  -- Note, should also use a specific date format
  xlsx_writer.add_cell(workbook, sheet, 3, 4, value_ => 21.21); 

  xlsx     := xlsx_writer.create_xlsx(workbook);

  blob_wrapper.to_file('XLSX_WRITER_TEST_DIR', '02_fill_cells.xlsx', xlsx);

end;
/

@after_test_item 02_fill_cells
