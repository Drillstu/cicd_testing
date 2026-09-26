Class tests.TestSoma Extends %UnitTest.TestCase
{

Method TestSomaCenarioSimples()
{
    // 1. Cenário: Somar 4 e 6 deve resultar em 10
    Set resultadoObtido = ##class(util.Teste).Soma(4, 6)
    Set resultadoEsperado = 10

    // 2. Asserção: Pergunta ao IRIS se o obtido é iguial ao esperado
    Do $$$AssertEquals(resultadoObtido, resultadoEsperado, "Testando soma simples de 4 + 6")
}

Method TestSomaComNegativos()
{
    // Outro cenário: Somar 5 com -2 deve resultar em 3
    Set resultadoObtido = ##class(util.Teste).Soma(5, -2)
    Do $$$AssertEquals(resultadoObtido, 3, "Testando soma envolvendo números negativos")
}
}
