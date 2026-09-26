Class util.Teste Extends %RegisteredObject
{
Property A As %Integer [ InitialExpression = 0 ];

Property B As %Integer [ InitialExpression = 0 ];

ClassMethod ImprimeResultado() {
    Do ..Soma(4, 6)
}
ClassMethod Soma(pNumero1 As %Integer, pNumero2 As %Integer) As %Integer {
    Return pNumero1 + pNumero2
}
}