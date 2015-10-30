set define off
create or replace package body xlsx_writer as -- {{{
-- vi: foldmarker={{{,}}}

  procedure ap (b in out blob, v in varchar2) is -- {{{
  begin
    dbms_lob.append(b, utl_raw.cast_to_raw(v));
  end ap; -- }}}

  function start_xml_blob return blob is -- {{{
    ret blob;
  begin
    dbms_lob.createTemporary(ret, true);
    
    ap(ret,q'{<?xml version="1.0" encoding="utf-8"?>
    }');

    return ret;

  end start_xml_blob; -- }}}

  procedure add_attr(b          in out blob, -- {{{
                     attr_name         varchar2,
                     attr_value        varchar2) is
  begin
    ap(b, ' ' || attr_name || '="' || attr_value || '"');
  end add_attr; -- }}}

  function start_book return book_r is -- {{{
    ret book_r;
  begin

    ret.sheets          := new sheet_t           ();

    ret.cell_styles     := new cell_style_t      ();
    ret.borders         := new border_t          ();
    ret.fonts           := new font_t            ();
    ret.fills           := new fill_t            ();
    ret.num_fmts        := new num_fmt_t         ();
    ret.shared_strings  := new shared_string_t   ();
    ret.medias          := new media_t           ();
    ret.drawings        := new drawing_t         ();

    return ret;

  end start_book; -- }}}

  function  add_sheet(xlsx in out book_r, -- {{{
                      name_       varchar2) return integer is

    ret sheet_r;
  begin

    ret.name_      := name_;

    ret.col_widths := new col_width_t();
    ret.sheet_rels := new sheet_rel_t();

    xlsx.sheets.extend;
    xlsx.sheets(xlsx.sheets.count) := ret;

    return xlsx.sheets.count;

  end add_sheet; -- }}}

  procedure add_sheet_rel     (xlsx        in out book_r, -- {{{
                               sheet              integer,
                               raw_               varchar2)
  is
  begin


    xlsx.sheets(sheet).sheet_rels.extend;
    xlsx.sheets(sheet).sheet_rels(xlsx.sheets(sheet).sheet_rels.count). raw_ := raw_;

  end add_sheet_rel; -- }}}

  procedure add_media         (xlsx        in out book_r, -- {{{
                               b                  blob,
                               name_              varchar2) is
  begin
  
    xlsx.medias.extend;
    xlsx.medias(xlsx.medias.count).b     := b;
    xlsx.medias(xlsx.medias.count).name_ := name_;


  end add_media; -- }}}

  procedure add_drawing       (xlsx        in out book_r, -- {{{
                               raw_               varchar2) is
  begin

    xlsx.drawings.extend;
    xlsx.drawings(xlsx.drawings.count).raw_ := raw_;
  end add_drawing; -- }}}

  -- {{{ Rows and Columns

  function col_to_letter(c integer) return varchar2 is -- {{{
  begin

    if c < 27 then
       return substr('ABCDEFGHIJKLMNOPQRSTUVWXYZ', c, 1);
    end if;

    raise_application_error(-20800, 'TODO: Implement me, col_to_letter for ' || c);
    
  end col_to_letter; -- }}}

  procedure col_width         (xlsx    in out book_r,-- {{{
                               sheet          integer,
                               start_col      integer,
                               end_col        integer,
                               width          number
                          --   style          number
                               ) is
    r col_width_r;
  begin

    r.start_col := start_col;
    r.end_col   := end_col;
    r.width     := width;
--  r.style     := style;


    xlsx.sheets(sheet).col_widths.extend;
    xlsx.sheets(sheet).col_widths(xlsx.sheets(sheet).col_widths.count) := r;

  end col_width; -- }}}

  function does_row_exist(xlsx  in out book_r, -- {{{
                          sheet        integer,
                          r            integer) return boolean is
  begin

     if xlsx.sheets(sheet).rows_.exists(r) then
        return true;
     end if;

     return false;

  end does_row_exist; -- }}}

  procedure add_row(xlsx     in out book_r, -- {{{
                    sheet           integer,
                    r               integer,
                    height          number := null) is
  begin

      if does_row_exist(xlsx, sheet, r) then
         raise_application_error(-20800, 'row ' || r || ' already exists');
      end if;

      xlsx.sheets(sheet).rows_(r).cells  := new cell_t();

      xlsx.sheets(sheet).rows_(r).height := height;

  end add_row; -- }}}

  procedure add_cell          (xlsx    in out book_r, -- {{{
                               sheet         integer,
                               r             integer,
                               c             integer,
                               style_id      integer,
                               text          varchar2 := null,
                               value_        number   := null,
                               formula       varchar2 := null) is
  begin

    if not does_row_exist(xlsx, sheet, r) then
       add_row(xlsx, sheet, r);
    end if;

    if style_id is null then
       raise_application_error(-20800, 'style id is null for cell ' || r || '/' || c);
    end if;

    xlsx.sheets(sheet).rows_(r).cells.extend;
    xlsx.sheets(sheet).rows_(r).cells(xlsx.sheets(sheet).rows_(r).cells.count).c        := c;
    xlsx.sheets(sheet).rows_(r).cells(xlsx.sheets(sheet).rows_(r).cells.count).style_id := style_id;
    xlsx.sheets(sheet).rows_(r).cells(xlsx.sheets(sheet).rows_(r).cells.count).value_   := value_;
    xlsx.sheets(sheet).rows_(r).cells(xlsx.sheets(sheet).rows_(r).cells.count).formula  := formula;

    if text is not null then -- {{{
       xlsx.shared_strings.extend;
       xlsx.shared_strings(xlsx.shared_strings.count).val := replace(
                                                             replace(
                                                             replace(text, '&', '&amp;'),
                                                                           '>', '&lt;' ),
                                                                           '<', '&gt;' );
 
       xlsx.sheets(sheet).rows_(r).cells(xlsx.sheets(sheet).rows_(r).cells.count).shared_string_id := xlsx.shared_strings.count-1;
    end if; -- }}}

       

  end add_cell; -- }}}

  -- }}}

  -- {{{ Related to styles
  --
  function add_font         (xlsx     in out book_r, -- {{{
                             name            varchar2,
                             size_           number,
                             color           varchar2 := null,
                             u               boolean  := false,
                             b               boolean  := false) return integer is
  begin

      xlsx.fonts.extend;
      xlsx.fonts(xlsx.fonts.count).name  := name; 
      xlsx.fonts(xlsx.fonts.count).size_ := size_; 
      xlsx.fonts(xlsx.fonts.count).color := color; 
      xlsx.fonts(xlsx.fonts.count).u     := u; 
      xlsx.fonts(xlsx.fonts.count).b     := b; 

      return xlsx.fonts.count; -- Not returning xlsx.fonts.count because of default font.

  end add_font; -- }}}

  function add_fill        (xlsx     in out book_r, -- {{{
                            raw_            varchar2) return integer is

  begin

    xlsx.fills.extend;
    xlsx.fills(xlsx.fills.count).raw_ := raw_;

    return xlsx.fills.count + 1;  -- +1 instead of -1 because there are two default fills.

  end add_fill; -- }}}

  function add_border      (xlsx     in out book_r, -- {{{
                            raw_            varchar2) return integer is
  begin

    xlsx.borders.extend;
    xlsx.borders(xlsx.borders.count).raw_ := raw_;

    return xlsx.borders.count; -- Return count instead of count-1 because the empty border is default
  end add_border; -- }}}

  function add_cell_style  (xlsx       in out book_r, -- {{{
                            font_id           integer  , -- := 0,
                            fill_id           integer  := 0,
                            border_id         integer  := 0,
                            num_fmt_id        integer  := 0,
                            raw_within        varchar2 := null) return integer is

    rec cell_style_r;
  begin

    rec.font_id    := font_id;
    rec.fill_id    := fill_id;
    rec.border_id  := border_id;
    rec.num_fmt_id := num_fmt_id;
    rec.raw_within := raw_within;


    xlsx.cell_styles.extend;
    xlsx.cell_styles(xlsx.cell_styles.count) := rec;

    return xlsx.cell_styles.count; -- Not returning count -1 because of «default style»

  end add_cell_style; -- }}}

  function add_num_fmt     (xlsx     in out book_r, -- {{{
                            raw_            varchar2,
                            return_id       integer) return integer is

  begin

    xlsx.num_fmts.extend;
    xlsx.num_fmts(xlsx.num_fmts.count).raw_ := raw_;

--  return xlsx.num_fmts.count - 1;
    return return_id;

  end add_num_fmt; -- }}}

  
  -- }}}

  -- {{{ Blob generators

  function docProps_app return blob is -- {{{
    ret blob;
  begin

    ret := start_xml_blob;

    ap(ret, '<Properties xmlns="http://schemas.openxmlformats.org/officeDocument/2006/extended-properties" xmlns:vt="http://schemas.openxmlformats.org/officeDocument/2006/docPropsVTypes">');
    ap(ret, '</Properties>');

    return ret;

  end docProps_app; -- }}}

  function xl_worksheets_sheet(xlsx in out book_r, -- {{{
                              sheet        integer) return blob is

    ret blob;
  begin

    ret := start_xml_blob;

    ap(ret, '<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships" xmlns:mc="http://schemas.openxmlformats.org/markup-compatibility/2006" xmlns:x14ac="http://schemas.microsoft.com/office/spreadsheetml/2009/9/ac" mc:Ignorable="x14ac">');


    if xlsx.sheets(sheet).col_widths.count > 0 then -- {{{
      ap(ret, '<cols>');

      for i in 1 .. xlsx.sheets(sheet).col_widths.count loop -- {{{

        ap(ret, '<col');

        add_attr(ret, 'min'        , xlsx.sheets(sheet).col_widths(i).start_col);
        add_attr(ret, 'max'        , xlsx.sheets(sheet).col_widths(i).end_col  );
        add_attr(ret, 'width'      , xlsx.sheets(sheet).col_widths(i).width    );
--      add_attr(ret, 'style'      , xlsx.sheets(sheet).col_widths(i).style    );
        add_attr(ret, 'customWidth', 1);

        ap (ret, '/>');

      end loop; -- }}}

      ap(ret, '</cols>');
    end if; -- }}}

    ap(ret, '<sheetData>'); -- {{{

    declare
      r pls_integer;
    begin
      r := xlsx.sheets(sheet).rows_.first;
      while r is not null loop
 
        ap(ret, '<row');
        add_attr(ret, 'r', r);

        if xlsx.sheets(sheet).rows_(r).height is not null then
           add_attr(ret, 'ht', xlsx.sheets(sheet).rows_(r).height);
           add_attr(ret, 'customHeight', 1);
        end if;

        ap(ret, '>');
 
        if xlsx.sheets(sheet).rows_(r).cells.count = 0 then
           raise_application_error(-20800, 'Row ' || r || ' does not contain any cells');
        end if;

        for c in 1 .. xlsx.sheets(sheet).rows_(r).cells.count loop

          ap(ret, '<c');


          add_attr(ret, 'r', col_to_letter(xlsx.sheets(sheet).rows_(r).cells(c).c) || r);
          add_attr(ret, 's', xlsx.sheets(sheet).rows_(r).cells(c).style_id);

          if xlsx.sheets(sheet).rows_(r).cells(c).shared_string_id is not null then
             add_attr(ret, 't', 's'); -- Type is String
          end if;

          ap(ret, '>');


          if xlsx.sheets(sheet).rows_(r).cells(c).formula is not null then
             ap(ret, '<f>' || xlsx.sheets(sheet).rows_(r).cells(c).formula || '</f>');
          end if;

          if xlsx.sheets(sheet).rows_(r).cells(c).value_ is not null then
             ap(ret, '<v>' || xlsx.sheets(sheet).rows_(r).cells(c).value_ || '</v>');
          end if;

          if xlsx.sheets(sheet).rows_(r).cells(c).shared_string_id is not null then
             ap(ret, '<v>' || xlsx.sheets(sheet).rows_(r).cells(c).shared_string_id || '</v>');
          end if;


          ap(ret, '</c>');

        end loop;
        
        r := xlsx.sheets(sheet).rows_.next(r);
 
        ap(ret, '</row>');
      end loop;
    end;

    ap(ret, '</sheetData>'); -- }}}

    ap(ret, '<pageMargins left="0.36000000000000004" right="0.2" top="1" bottom="1" header="0.5" footer="0.5" />');
  
    ap(ret, '<pageSetup paperSize="9" scale="67" orientation="landscape" horizontalDpi="4294967292" verticalDpi="4294967292" />');
  
    for d in 1 .. xlsx.drawings.count loop 
      ap(ret, '<drawing r:id="rId' || d || '" /> ');
    end loop;

    ap(ret, '</worksheet>');

    return ret;

  end xl_worksheets_sheet; -- }}}

  function xl_styles(xlsx in book_r) return blob is -- {{{
    ret blob;
  begin

    ret := start_xml_blob;

    ap(ret, '<styleSheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:mc="http://schemas.openxmlformats.org/markup-compatibility/2006" xmlns:x14ac="http://schemas.microsoft.com/office/spreadsheetml/2009/9/ac" mc:Ignorable="x14ac">');

    if xlsx.num_fmts.count > 0 then -- {{{
       ap(ret, '<numFmts>');

       for n in 1 .. xlsx.num_fmts.count loop
           ap(ret, '<numFmt ' || xlsx.num_fmts(n).raw_ || ' />');
       end loop;

       ap(ret, '</numFmts>');

    end if; -- }}}

    ap(ret, '<fonts>'); -- {{{

    ap(ret, '<font><sz val="11"/><name val="Calibri" /></font>'); -- Default font.

    for f in 1 .. xlsx.fonts.count loop -- {{{

      ap(ret, '<font><name val="' || xlsx.fonts(f).name  || '"/>' ||
                    '  <sz val="' || xlsx.fonts(f).size_ || '"/>');

      if xlsx.fonts(f).color is not null then
         ap(ret, '<color ' || xlsx.fonts(f).color || '/>');
      end if;

      if xlsx.fonts(f).b then
         ap(ret, '<b/>');
      end if;

      if xlsx.fonts(f).u then
         ap(ret, '<u/>');
      end if;

      ap(ret, '</font>');

    end loop; -- }}}

    ap(ret, '</fonts>'); -- }}}

    ap(ret, '<fills>'); -- {{{

--  the first two pattern fills seem to somehow be default...
    ap(ret, q'{
      <fill><patternFill patternType="none"    /></fill>
      <fill><patternFill patternType="gray125" /></fill>
    }');

    for f in 1 .. xlsx.fills.count loop -- {{{

      ap(ret, '<fill>' || xlsx.fills(f).raw_ || '</fill>');

    end loop; -- }}}

    ap(ret, '</fills>'); -- }}}

    ap(ret, '<borders>'); -- {{{

    -- Add default «empty» border
    ap(ret, '<border><left/><right/><top/><bottom/><diagonal/></border>');


    for b in 1 .. xlsx.borders.count loop -- {{{
        ap(ret, '<border>' || xlsx.borders(b).raw_ || '</border>');
    end loop; -- }}}

    ap(ret, '</borders>'); -- }}}

    -- <cellStyleXfs>  Huh, what's this for? -- {{{
    ap(ret, q'{<cellStyleXfs>
    <xf numFmtId="0" fontId="0" fillId="0" borderId="0" />
    </cellStyleXfs>}'); -- }}}

    ap(ret, '<cellXfs>'); -- {{{ Cell Styles

 -- Default cell style?
    ap(ret, '<xf numFmtId="0" fontId="0" fillId="0" borderId="0" xfId="0" />');

    for c in 1 .. xlsx.cell_styles.count loop -- {{{

        ap(ret, '<xf');

        add_attr(ret, 'numFmtId', xlsx.cell_styles(c).num_fmt_id);
        add_attr(ret, 'fillId'  , xlsx.cell_styles(c).fill_id   );
        add_attr(ret, 'fontId'  , xlsx.cell_styles(c).font_id   );
        add_attr(ret, 'borderId', xlsx.cell_styles(c).border_id );
        ap(ret, '>');

        if xlsx.cell_styles(c).raw_within is not null then
           ap(ret, xlsx.cell_styles(c).raw_within);
        end if;

        ap(ret, '</xf>');

    end loop; -- }}}

  ap(ret, '</cellXfs>'); -- }}}

    ap(ret, q'{<cellStyles count="33">
      <cellStyle name="Normal" xfId="0" builtinId="0" />
   </cellStyles>}');

    ap(ret, q'{<dxfs count="0" />}');


    ap(ret, q'{</styleSheet>}');

    return ret;

  end xl_styles; -- }}}

  function xl_sharedStrings(xlsx book_r) return blob is -- {{{
    ret blob;
  begin

    ret := start_xml_blob();

    ap(ret, '<sst xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" count="24" uniqueCount="24">');

    for s in 1 .. xlsx.shared_strings.count loop
      ap(ret, '<si><t xml:space="preserve">' || xlsx.shared_strings(s).val || '</t></si>');
    end loop;

    ap(ret, '</sst>');
    return ret;
  end xl_sharedStrings; -- }}}

  function xl_workbook(xlsx in out book_r -- {{{
  ) return blob is
    ret blob := start_xml_blob;
  begin


    ap(ret, '<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">'); -- {{{

    ap(ret, '<sheets>'); -- {{{

    for s in 1 .. xlsx.sheets.count loop -- {{{

        ap(ret, '<sheet');

        add_attr(ret, 'name'   , xlsx.sheets(s).name_);
        add_attr(ret, 'sheetId', s                   );
        add_attr(ret, 'r:id'   ,'rId' || s           );

        ap(ret, '/>');

     end loop; -- }}}

    ap(ret, '</sheets>'); -- }}}

--  ap(ret, '<calcPr calcOnSave="0" />');
    ap(ret, '</workbook>'); -- }}}

    return ret;
  
  end xl_workbook; -- }}}

  function rels_rels      (xlsx in out book_r) return blob is -- {{{
    ret blob;
  begin

    ret := start_xml_blob();

    ap(ret, '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">');
      ap(ret, '<Relationship Id="rId3" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/extended-properties" Target="docProps/app.xml"  />');
      ap(ret, '<Relationship Id="rId2" Type="http://schemas.openxmlformats.org/package/2006/relationships/metadata/core-properties"   Target="docProps/core.xml" />');
      ap(ret, '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument"      Target="xl/workbook.xml"   />');
    ap(ret, '</Relationships>');

    return ret;

  end rels_rels; -- }}}

  function docProps_core  (xlsx in out book_r) return blob is -- {{{
    ret blob := start_xml_blob;
  begin

    ap(ret, '<cp:coreProperties xmlns:cp="http://schemas.openxmlformats.org/package/2006/metadata/core-properties" xmlns:dc="http://purl.org/dc/elements/1.1/" xmlns:dcterms="http://purl.org/dc/terms/" xmlns:dcmitype="http://purl.org/dc/dcmitype/" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">');
    ap(ret, '</cp:coreProperties>');

    return ret;

  end docProps_core; -- }}}

  function xl_rels_workbook           (xlsx in out book_r) return blob is -- {{{
    ret blob := start_xml_blob;
    rId integer := 1;

    procedure add_relationship(type_ varchar2, target varchar2) is -- {{{
    begin
      
      ap(ret, '<Relationship');

      add_attr(ret, 'Id'    , 'rId' || rId); rId := rId + 1;
      add_attr(ret, 'Type'  ,  type_      );
      add_attr(ret, 'Target',  target     );

      ap(ret, '/>');


    end add_relationship; -- }}}
  begin

    ap(ret, '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">');

      for s in 1 .. xlsx.sheets.count loop
        add_relationship('http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet', 'worksheets/sheet' || s || '.xml');
      end loop;

      add_relationship('http://schemas.openxmlformats.org/officeDocument/2006/relationships/sharedStrings', 'sharedStrings.xml');
      add_relationship('http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles'       , 'styles.xml'       );

    ap(ret, '</Relationships>');

    return ret;

  end xl_rels_workbook; -- }}}

  function xl_drawings_rels_drawing1  (xlsx in out book_r) return blob is -- {{{
    ret blob := start_xml_blob;
  begin

    ap(ret, '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">');

    for m in 1 .. xlsx.medias.count loop
      ap(ret, '<Relationship Id="rId' || m || '" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/image" Target="../media/' || xlsx.medias(m).name_ || '" />');
    end loop;

    ap(ret, '</Relationships>');

    return ret;

  end xl_drawings_rels_drawing1; -- }}}

  function xl_worksheets_rels_sheet(xlsx in out book_r, sheet integer)  return blob is -- {{{
    ret blob;
  begin


    for r in 1 .. xlsx.sheets(sheet).sheet_rels.count loop

      if ret is null then
         ret := start_xml_blob;
         ap(ret, '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">');
      end if;

      ap(ret, xlsx.sheets(sheet).sheet_rels(r).raw_);

    end loop;


    if ret is not null then
       ap(ret, '</Relationships>');
    end if;

    return ret;
  end xl_worksheets_rels_sheet; -- }}}

  function content_types(xlsx in out book_r) return blob is -- {{{
    ret blob := start_xml_blob;
  begin

    ap(ret, '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">');


      ap(ret, '<Default Extension="png"  ContentType="image/png"                                                />');
      ap(ret, '<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml" />');
--    ap(ret, '<Default Extension="xml"  ContentType="application/xml"                                          />');

      ap(ret, '<Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml" />');

      for s in 1 ..xlsx.sheets.count loop
        ap(ret, '<Override PartName="/xl/worksheets/sheet' || s || '.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml" />');
      end loop;

--    ap(ret, '<Override PartName="/xl/theme/theme1.xml"      ContentType="application/vnd.openxmlformats-officedocument.theme+xml" />');
      ap(ret, '<Override PartName="/xl/styles.xml"            ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"        />');
      ap(ret, '<Override PartName="/xl/sharedStrings.xml"     ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sharedStrings+xml" />');
      ap(ret, '<Override PartName="/xl/drawings/drawing1.xml" ContentType="application/vnd.openxmlformats-officedocument.drawing+xml"                     />');
      ap(ret, '<Override PartName="/xl/calcChain.xml"         ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.calcChain+xml"     />');
      ap(ret, '<Override PartName="/docProps/core.xml"        ContentType="application/vnd.openxmlformats-package.core-properties+xml"                    />');
      ap(ret, '<Override PartName="/docProps/app.xml"         ContentType="application/vnd.openxmlformats-officedocument.extended-properties+xml"         />');

    ap(ret, '</Types>');

    return ret;

  end content_types; -- }}}

  -- }}}

  function create_xlsx(xlsx in out book_r) return blob is -- {{{

    xlsx_b   blob;

    xb_xl_worksheets_rels_sheet   blob;

    procedure add_blob_to_zip(zip      in out blob, -- {{{
                              filename        varchar2,
                              b               blob) is

      b_ blob;
    begin

      b_ := b;

      zipper.addFile(zip, filename, b_);

      dbms_lob.freeTemporary(b_);


    end add_blob_to_zip; -- }}}

  begin

    dbms_lob.createTemporary(xlsx_b, true);

    for s in 1 .. xlsx.sheets.count loop
       xb_xl_worksheets_rels_sheet  := xl_worksheets_rels_sheet  (xlsx, s);
       if xb_xl_worksheets_rels_sheet is not null then
          zipper.addFile(xlsx_b, 'xl/worksheets/_rels/sheet' || s || '.xml.rels', xb_xl_worksheets_rels_sheet);
       end if;
    end loop;


    for s in 1 .. xlsx.sheets.count loop
         zipper.addFile(xlsx_b, 'xl/worksheets/sheet' || s || '.xml', xl_worksheets_sheet       (xlsx, s));
    end loop;


    add_blob_to_zip(xlsx_b, '_rels/.rels'                        , rels_rels                 (xlsx));
    add_blob_to_zip(xlsx_b, 'docProps/app.xml'                   , docProps_app              ()    );
    add_blob_to_zip(xlsx_b, 'docProps/core.xml'                  , docProps_core             (xlsx));
    add_blob_to_zip(xlsx_b, 'xl/_rels/workbook.xml.rels'         , xl_rels_workbook          (xlsx));
    add_blob_to_zip(xlsx_b, 'xl/drawings/_rels/drawing1.xml.rels', xl_drawings_rels_drawing1 (xlsx));

    for d in 1 .. xlsx.drawings.count loop
      add_blob_to_zip(xlsx_b, 'xl/drawings/drawing' || d || '.xml',  utl_raw.cast_to_raw(xlsx.drawings(d).raw_));
    end loop;

    for m in 1 .. xlsx.medias.count loop
      add_blob_to_zip(xlsx_b, 'xl/media/' || xlsx.medias(m).name_, xlsx.medias(m).b);
    end loop;

    add_blob_to_zip(xlsx_b, 'xl/sharedStrings.xml'               , xl_sharedStrings          (xlsx));
    add_blob_to_zip(xlsx_b, 'xl/styles.xml'                      , xl_styles                 (xlsx));
    add_blob_to_zip(xlsx_b, 'xl/workbook.xml'                    , xl_workbook               (xlsx));
    add_blob_to_zip(xlsx_b, '[Content_Types].xml'                , content_types             (xlsx));

    zipper.finish(xlsx_b);

    return xlsx_b;

  end create_xlsx; -- }}}

  begin
    dbms_session.set_nls('nls_numeric_characters', '''. ''');

end xlsx_writer; -- }}}
/
show errors

