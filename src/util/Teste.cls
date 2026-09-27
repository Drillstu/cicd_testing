Class src.util.Teste Extends %RegisteredObject
{
Property A As %Integer [ InitialExpression = 0 ];

Property B As %Integer [ InitialExpression = 0 ];

ClassMethod Soma(pNumero1 As %Integer, pNumero2 As %Integer) As %Integer {
    Quit pNumero1 + pNumero2
}
}