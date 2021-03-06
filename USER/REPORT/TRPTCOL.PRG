//---------------------------------------------------------------------------//
//                                                                           //
//          Clase para el tratamiento de listados columnas                   //
//                                                                           //
//---------------------------------------------------------------------------//

#include "FiveDOS.ch"

#ifndef CRLF
    #define CRLF Chr( 13 ) + Chr( 10 )
#endif

static __ThisRpt        // Guardo el 'Report' para las funciones amigas y no
                        // tener que hacer virguer�as con 'Prepro'

//---------------------------------------------------------------------------//

CLASS TRptCol FROM TReport

    DATA bOnGroup,      ;
         bGroup              AS BLOCK

    DATA cTxtEndGrp,    ;
         cTxtEndPg,     ;
         cTxtEndLst,    ;
         cColSep,       ;
         cHeadSepH,     ;
         cHeadSep,      ;
         cGroup             AS CHARACTER

    DATA nColumn            AS NUMERIC

    DATA aColumns,      ;
         aTotal,        ;
         aTotalGrp,     ;        
         aTotalPg           AS ARRAY

    DATA lEjectGrp, ;
         lGroup, ;
         lTotalPg, ;
         lTotal, ;
         lTotalGrp          AS LOGICAL

    DATA uGroupOld          AS ALL

    METHOD New( cCanal, cAlias, aHead, nMrgUp, nMrgLeft, cHeadSepH, ;
                        cHeadSep, cColSep, lTotal, lPage, nPosPg ) CONSTRUCTOR

//-------------------------------------------- Impresores de l�nesa -----
    METHOD SayPage()

    METHOD SayTotalGrp()
    METHOD SayTotalPg()
    METHOD SayTotalLst()

//-------------------------------------------- Generadores de l�neas -----
    METHOD GenNames()
    METHOD GenHeadSep()
    METHOD GenDetail()
    METHOD GenSep()

//-------------------------------------------- Operaciones con columnas -
    METHOD AddColumn( oColumn )
    METHOD DelColumn( nColumn )
    METHOD InsColumn( oColumn, nColumn )
    METHOD AutoColumn()

//-------------------------------------------- Operaciones con impresoras -

    METHOD CtrGroup()
    METHOD oGroup( bGroup, cGroup, cTxtEndGrp, lSummary, bOnGroup, lEjectGrp )

    METHOD CtrlPage()
    METHOD CtrlReport()

    METHOD LenRel( nCol )

END CLASS

//---------------------------------------------------------------------------//

METHOD New( cCanal, cAlias, aHead, nMrgUp, nMrgLeft, cHeadSepH, ;
            cHeadSep, cColSep, lTotalPg, lTotal, lPage, nPosPg ) CLASS TRptCol

    DEFAULT cHeadSepH := "-",                 ;
            cHeadSep  := " ",                 ;
            cColSep   := " ",                 ;
            lTotalPg  := .f.,                 ;
            lTotal    := .f.

    ::Super:New( cCanal, cAlias, aHead, nMrgUp, nMrgLeft, lPage, nPosPg )

    ::cHeadSepH:= cHeadSepH                // Separador de cabecera horizontal
    ::cHeadSep := cHeadSep                 // Separador de cabecera vertical
    ::cColSep  := cColSep                  // Separador de columna
    ::lTotal   := lTotal                   // Hay total general
    ::lTotalPg := lTotalPg                 // Hay total p�gina

    ::aColumns := {}                       // Tabla de objetos TRColumn
    ::nColumn  := 0                        // N�mero de columnas

    ::lTotalGrp  := .f.                    // Hay total por grupo
    ::lEjectGrp  := .f.                    // Hay salto despu�s de cada grupo

    ::aTotal    := {}                      // Tabla de totales
    ::aTotalGrp := {}                      // Tabla total grupo
    ::aTotalPg  := {}                      // Tabla total p�gina

    ::bOnGroup := { || nil }               // Se evalua al principio del grupo
    ::bGroup   := { || nil }               // Valor del grupo
    ::lGroup   := .f.                      // Control de si hay grupos

    ::cGroup      := ::cColSep + "Grupo: "         // Literal del grupo
    ::cTxtEndGrp  := ::cColSep + "Total Grp.: "  // Texto fin grupo
    ::cTxtEndPg   := ::cColSep + "Total pg.: "  // Texto fin p�gina
    ::cTxtEndLst  := ::cColSep + "Total fin: "  // Texto fin listado

    __ThisRpt := Self     // Para a�adir columnas y grupo

return Self

//---------------------------------------------------------------------------//

METHOD CtrlReport() CLASS TRptCol

    DbSelectArea( ::cAlias )

    if ::nColumn == 0
        ::AutoColumn()    // Si no hay columnas hace un autocolumn
    endif

    // Controla la primera entrada ........................................

    if eval( ::bWhile )     

        if ::nPgLines < len( ::aHead ) + 3
            ::Say( "La cabecera es muy grande" )
            ::Eject()
            return nil              // <------------- Ojo se sale
        endif

        ::nWidth := len( ::GenNames() )  // Calculo del ancho total

        ::SayHead()
        ::SayLine( ::GenNames() )
        ::SayLine( ::GenHeadSep() )

        if ::lGroup
            eval( ::bOnGroup )
            ::uGroupOld := eval( ::bGroup )
            ::SayLine( Stuff( ::GenSep( "�" ), 1, ;
                        len( ::cGroup + ::uGroupOld ), ;
                        ::cGroup + ::uGroupOld ) )
        endif

    endif

    while eval( ::bWhile ) .and. !::lEnd

        // Si se presiona ESCape se corta el listado:

        if NextKey() == 27    //  K_ESC
            CLEAR TYPEAHEAD   // Por si controla el ESCape para otros procesos
            if Alert( "Listado interrumpido por el usuario", ;
                        { " Terminar ", " Continuar " } ) == 1
                ::lEnd := .t.
                LOOP
            endif
        endif

        if !eval(::bFor)
            ::Skip( 1 )
            LOOP
        endif

        ::SayLine( ::GenDetail() )

        ::Skip( 1 )

     // Control de grupo:
        if ::lGroup
            ::CtrGroup()
        endif

    end while

    // Controla �ltima entrada ....................................

    if ::lGroup
        ::SayTotalGrp()     // Para el grupo
        if ::lEjectGrp      // Hay salto despu� de cada grupo
            ::SayBlank( ::nPgLines - ( ::nLines + ::nZonInf ) )
        endif
    endif

    ::SayBlank( ::nPgLines - ( ::nLines + ::nZonInf + 1 ) )  // Salto al final
    ::Say( space( ::nMrgLeft ) + ::GenHeadSep() + CRLF )

    if( ::lTotalPg, ::SayTotalPg(),  ::SayBlank( 1 ) )
    if( ::lTotal,   ::SayTotalLst(), ::SayBlank( 1 ) )
    if( ::lPage,    ( ::Say( space( ::nMrgLeft ) + ::GenNPg() + CRLF + ;
                               CRLF ), ::nLines += 2 ), ::SayBlank( 2 ) )

    ::nLines := 0       // Por si hay un Eject que lo calcule bien

return nil

//---------------------------------------------------------------------------//

METHOD AutoColumn() CLASS TRptCol

    local n := 0
    local lSummary := .f.           // Por defecto
    local cHeading := ""
    local nFCount  := FCount()
    local oCol

    local xVal

    for n := 1 to nFCount

        cHeading := FieldName( n )

        xVal := FieldGet( n )

        lSummary := ( ValType( xVal ) == "N" )

        oCol := TRColumn():New( FieldBlock( cHeading ), cHeading,, lSummary, )

        if( lSummary, oCol:nWidth := 10, ) // Hace que la anchura sea 10

        ::AddColumn( oCol )

    next

return nil

//----------------------------------------------------------------------------//

METHOD CtrlPage() CLASS TRptCol

    if ::nLines >= ::nPgLines - ::nZonInf
        ::SayPage( 0 )
        eval( ::bEndPage )
        ::SayHead()
        ::SayLine( ::GenNames() )
        ::SayLine( ::GenHeadSep() )
    endif

return nil

//----------------------------------------------------------------------------//
// Estructura de ::aTotalGrp := { { nTotal, ::nColumn } }
//
METHOD SayTotalGrp() CLASS TRptCol

    local nNum      := 0
    local nCharTxt  := len( ::cTxtEndGrp )
    local nLenTotal := 0
    local nLTotal   := len( ::cColSep )
    local nLenRel   := 0
    local nAt       := 0
    local nLenATGrp := len( ::aTotalGrp )
    local cOut      := Stuff( ::GenSep( "�" ), 1, nCharTxt, ::cTxtEndGrp )

    #ifndef ThisCol
        #define ThisCol ::aColumns[ ::aTotalGrp[ nNum, 2 ] ]
    #endif

    for nNum := 1 to nLenATGrp

        ::aTotalGrp[ nNum, 1 ] := ThisCol:nTotal - ::aTotalGrp[ nNum, 1 ]

        nLenTotal := nLTotal
        nLenTotal += ::LenRel( ::aTotalGrp[ nNum, 2 ] )
        nLenRel := ThisCol:nWidth
        nAt := nLenTotal - nLenRel
        cOut := Stuff( cOut, nAt, nLenRel, ;
                        PadR( ThisCol:SetForm( ::aTotalGrp[ nNum, 1 ] ), ;
                              ThisCol:nWidth ) )

        ::aTotalGrp[ nNum, 1 ] := ThisCol:nTotal

    next

    #undef ThisCol

    ::SayLine( cOut )

return nil

//----------------------------------------------------------------------------//
//
METHOD SayPage() CLASS TRptCol

    if( ::lTotalPg, ( ::Say( space( ::nMrgLeft ) + ::GenHeadSep() + CRLF ), ;
                             ++::nLines, ::SayTotalPg() ), ::SayBlank( 2 ) )

    ::Super:SayPage()

return nil

//----------------------------------------------------------------------------//

METHOD SayTotalPg() CLASS TRptCol

    local nNum      := 0
    local nCharTxt  := len( ::cTxtEndPg )
    local nLenTotal := 0
    local nLTotal   := len( ::cColSep )
    local nLenATPg  := len( ::aTotalPg )
    local nLenRel   := 0
    local nAt       := 0
    local cOut      := Stuff( ::GenSep( "�" ), 1, nCharTxt, ::cTxtEndPg )

    #ifndef ThisCol
        #define ThisCol ::aColumns[ ::aTotalPg[ nNum, 2 ] ]
    #endif

    for nNum := 1 to nLenATPg

        ::aTotalPg[ nNum, 1 ] := ThisCol:nTotal - ::aTotalPg[ nNum, 1 ]

        nLenTotal := nLTotal
        nLenTotal += ::LenRel( ::aTotalPg[ nNum, 2 ] )
        nLenRel := ThisCol:nWidth
        nAt := nLenTotal - nLenRel
        cOut := Stuff( cOut, nAt, nLenRel, ;
                        PadR( ThisCol:SetForm( ::aTotalPg[ nNum, 1 ] ), ;
                              ThisCol:nWidth ) )

        ::aTotalPg[ nNum, 1 ] := ThisCol:nTotal

    next

    #undef ThisCol

    ::Say( space( ::nMrgLeft ) + cOut + CRLF )

return nil

//----------------------------------------------------------------------------//

METHOD SayTotalLst() CLASS TRptCol

    local nNum      := 0
    local nCharTxt  := len( ::cTxtEndLst )
    local nLenTotal := 0
    local nLTotal   := len( ::cColSep )
    local nLenAT    := len( ::aTotal )
    local nLenRel   := 0
    local nAt       := 0
    local cOut      := Stuff( ::GenSep( "�" ), 1, nCharTxt, ::cTxtEndLst )

    #ifndef ThisCol
        #define ThisCol ::aColumns[ ::aTotal[ nNum, 2 ] ]
    #endif

    for nNum := 1 to nLenAT

        ::aTotal[ nNum, 1 ] := ThisCol:nTotal - ::aTotal[ nNum, 1 ]

        nLenTotal := nLTotal
        nLenTotal += ::LenRel( ::aTotal[ nNum, 2 ] )
        nLenRel := ThisCol:nWidth
        nAt := nLenTotal - nLenRel
        cOut := Stuff( cOut, nAt, nLenRel, ;
                        PadR( ThisCol:SetForm( ::aTotal[ nNum, 1 ] ), ;
                              ThisCol:nWidth ) )

        ::aTotal[ nNum, 1 ] := ThisCol:nTotal

    next

    #undef ThisCol

    ::Say( space( ::nMrgLeft ) + cOut + CRLF )

return nil

//----------------------------------------------------------------------------//

METHOD CtrGroup() CLASS TRptCol

    local xGroup

    if ::uGroupOld != ( xGroup := eval( ::bGroup ) )
        ::uGroupOld := xGroup
        ::SayTotalGrp()
        if ::lEjectGrp      // Hay salto despu� de cada grupo
            ::SayBlank( ::nPgLines - ( ::nLines + ::nZonInf ) )
        endif
        if !::lEnd
           eval( ::bOnGroup )
           ::SayLine( Stuff( ::GenSep( "�" ), 1, ;
                        len( ::cGroup + ::uGroupOld ), ;
                        ::cGroup + ::uGroupOld ) )
       endif
    endif

return nil

//----------------------------------------------------------------------------//

METHOD GenNames() CLASS TRptCol

    local cVal := ::cColSep

     AEval( ::aColumns, { | oCol | cVal += oCol:cHeader + ::cColSep } )

return( cVal )

//----------------------------------------------------------------------------//

METHOD GenHeadSep() CLASS TRptCol

    local cVal := ::cHeadSep

    AEval( ::aColumns, { | oCol | cVal += PadC( "", oCol:nWidth, ::cHeadSepH ) + ;
                ::cHeadSep } )

return( cVal )

//----------------------------------------------------------------------------//
// Genera una linea con el ancho de una linea de detalle con separador y
// relleno opcionales
//
METHOD GenSep( cRe, cSep ) CLASS TRptCol

    local cVal := ""

    DEFAULT cRe := " ", ;
            cSep := ::cColSep

    cVal := cSep

    AEval( ::aColumns, { |oCol| cVal += PadC( "", oCol:nWidth, cRe ) + cSep } )

return( cVal )

//----------------------------------------------------------------------------//

METHOD GenDetail() CLASS TRptCol

    local cVal := ::cColSep

    AEval( ::aColumns, { | oCol | cVal += oCol:SetOut() + ::cColSep } )

return( cVal )

//----------------------------------------------------------------------------//

METHOD AddColumn( oColumn ) CLASS TRptCol

    AAdd( ::aColumns, oColumn )

    ++::nColumn

    if oColumn:lSummary
        if( ::lTotal,    AAdd( ::aTotal,     { 0, ::nColumn } ), )
        if( ::lTotalGrp, AAdd( ::aTotalGrp,  { 0, ::nColumn } ), )
        if( ::lTotalPg,  AAdd( ::aTotalPg,   { 0, ::nColumn } ), )
    endif

return nil

//----------------------------------------------------------------------------//

METHOD DelColumn( nColumn ) CLASS TRptCol

    ADel( ::aColumns, nColumn )
    ASize( ::aColumns, Len( ::aColumns ) -1 )

return nil

//----------------------------------------------------------------------------//

METHOD InsColumn( oColumn, nColumn ) CLASS TRptCol

    AIns( ::aColumns, nColumn )
    ::aColumns[ nColumn ] := oColumn

return nil

//----------------------------------------------------------------------------//
//
METHOD oGroup( bGroup, cGroup, cTxtEndGrp, lSummary, ;
                                    bOnGroup, lEjectGrp ) CLASS TReport
    
        DEFAULT bGroup     := { || nil },  ;
                bOnGroup   := { || nil },  ;
                bGroup     := { || nil },  ;
                cGroup     := ::cColSep + "Grupo > ", ;
                cTxtEndGrp := ::cColSep + "Total Grupo  > " ,;
                lEjectGrp  := .f.


        ::bGroup := if( ValType( bGroup ) != "B", ::ToBlock( bGroup ), bGroup )
        ::cGroup     := cGroup
        ::lTotalGrp  := lSummary
        ::cTxtEndGrp := cTxtEndGrp
        ::bOnGroup   := bOnGroup
        ::lEjectGrp  := lEjectGrp
        ::lGroup   := if( eval( ::bGroup ) != nil, .t., .f. )


return nil

//----------------------------------------------------------------------------//
// Devuelve tama�o del espaco que ocupa hasta la columna en cuestion
//
METHOD LenRel( nCol ) CLASS TRptCol

   local nLen := 0

   AEval( ::aColumns, { | oCol | nLen += len( ::cColSep ) + ;
                          oCol:nWidth }, , nCol )

return( nLen )

//----------------------------------------------------------------------------//

//----------------------------------------------------------------------------//
//
//  Funciones amigas para la creaci�n de columnas y grupo del listado
//
//      Si no se les pasa el objeto report asumen el actual
//
//----------------------------------------------------------------------------//
//
function RptAddColumn( bColumn, cHeader, nWidth, lSummary, cPicture, oReport )
    
    local oCol := TRColumn():New( bColumn, cHeader, nWidth, lSummary, cPicture )

    DEFAULT oReport := __ThisRpt

    oReport:AddColumn( oCol )

return( oCol )

//----------------------------------------------------------------------------//

function RptGroup( bGroup, cGroup, cTxtEndGrp, lSummary, ;
                    bOnGroup, lEjectGrp, oReport )

    local oRptGrp

    DEFAULT oReport := __ThisRpt

    oRptGrp := oReport:oGroup( bGroup, cGroup, cTxtEndGrp, lSummary, ;
                                bOnGroup, lEjectGrp )

return( oRptGrp )

//----------------------------------------------------------------------------//




