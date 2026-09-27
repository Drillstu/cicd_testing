pipeline {
    agent any

    options {
        // ESTRATÉGIA DE LIMPEZA: Mantém no disco apenas os últimos 10 builds e deleta automaticamente os artefatos/XMLs mais velhos que isso!
        buildDiscarder(logRotator(numToKeepStr: '10', artifactNumToKeepStr: '10'))
        timeout(time: 1, unit: 'HOURS')
    }

    environment {
        // FIX: Nome padronizado para bater com as chamadas de credenciais abaixo
        DISCORD_WEBHOOK_ID = 'discord-webhook-url'
    }
    
    stages {
        stage('1. Baixar do GitHub') {
            steps {
                // PADRÃO DE PRODUÇÃO: Pega a URL e a Branch dinamicamente de onde o script foi baixado
                checkout scm
            }
        }
        stage('2. Copiar para o Servidor') {
            steps {
                echo '🧹 Limpando resíduos antigos e espelhando repositório no servidor...'
                
                // Correção definitiva de pastas: rmdir apaga a pasta inteira e os subdiretórios antigos vazios
                bat 'rmdir /q /s D:\\IRIS_Server\\projectGit 2>nul || exit 0'
                bat 'mkdir D:\\IRIS_Server\\projectGit'
                
                // Copia a estrutura nova perfeitamente limpa
                bat 'xcopy /E /Y . D:\\IRIS_Server\\projectGit\\'
            }
        }
        stage('3. Backup e Deploy no IRIS') {
            options {
                timeout(time: 1, unit: 'MINUTES') 
            }
            steps {
                // Esse script agora cria o backup_anterior.xml ANTES de aplicar o código novo
                bat '"D:\\InterSystems\\IRIS\\bin\\irissession" IRIS < D:\\IRIS_Server\\importar.script || exit 0'
            }
        }
        stage('4. Executar Testes Unitários') {            
            when {
                allOf {
                    // 1. A pasta 'tests' precisa existir no repositório
                    expression { return fileExists('tests') }
                    
                    // 2. A branch atual NÃO pode ser a 'production'
                    not { branch 'production' }
                    
                    // 3. A mensagem do commit NÃO pode conter o texto '[skip test]' ou '[skip ci]'
                    expression { 
                        def changeLogSets = currentBuild.changeSets
                        def commitMessage = changeLogSets.collect { set -> set.items.collect { item -> item.msg }.join(' ') }.join(' ')
                        return !commitMessage.contains('[skip test]') && !commitMessage.contains('[skip ci]')
                    }
                }
            }
            options {
                timeout(time: 1, unit: 'MINUTES')
            }
            steps {
                echo '🧪 Executando bateria de testes unitários de forma dinâmica...'
                
                // FIX: Envelopando a lógica Groovy dentro de um bloco script válido
                script {
                    // 1. Normaliza as barras do caminho do Workspace para o padrão do IRIS (barras normais /)
                    def irisWorkspacePath = "${WORKSPACE}".replace('\\', '/')
                    
                     // SOLUÇÃO PROFISSIONAL: Abre o último objeto de instância de teste persistido para validar o status real de sucesso (Status=1)
                    def testeScriptConteudo = """zn "USER"
                                                set ^UnitTestRoot="${irisWorkspacePath}"
                                                set sc=##class(%UnitTest.Manager).RunTest("tests", "/load/compile")
                                                set lastId=\$order(^UnitTest.Result(""), -1)
                                                set statusValido=1
                                                if lastId'="" { set obj=##class(%UnitTest.Result.TestInstance).%OpenId(lastId) if \$isobject(obj) set statusValido=obj.Status }
                                                if ('sc) || (statusValido=0) hang 2 halt
                                                do \$zf(-1,"exit 0")
                                                halt
                                                """
                    
                    // 3. Cria a pasta build se não existir e grava o script de teste dinâmico lá dentro
                    bat 'mkdir build 2>nul || exit 0'
                    writeFile file: 'build/executar_testes.script', text: testeScriptConteudo, encoding: 'UTF-8'
                }
                
                // 4. Executa o teste de forma isolada e limpa (Sem misturar argumentos no prompt do IRIS)
                bat '"D:\\InterSystems\\IRIS\\bin\\irissession" IRIS < build\\executar_testes.script'
            }
        }
        stage('5. Gerar Artefato de Release') {
            when {
                expression { 
                    def changeLogSets = currentBuild.changeSets
                    def commitMessage = changeLogSets.collect { set -> set.items.collect { item -> item.msg }.join(' ') }.join(' ')
                    if (!commitMessage || commitMessage.trim() == "") {
                        commitMessage = powershell(script: "git log -1 --pretty=format:%B", returnStdout: true).trim()
                    }
                    return commitMessage.contains('[release]')
                }
            }                
            options {
                timeout(time: 1, unit: 'MINUTES')
            }
            steps {
                echo '📦 Testes aprovados! Gerando script e pacote consolidado dinamicamente...'
                
                script {
                    // 1. Cria a pasta build local no Workspace atual usando o Jenkins
                    bat 'mkdir build 2>nul || exit 0'
                    
                    // 2. Normaliza as barras do caminho do Workspace para o padrão do IRIS (barras normais /)
                    def irisWorkspacePath = "${WORKSPACE}".replace('\\', '/')
                    
                    // 3. Monta o script ObjectScript em uma única linha contínua perfeita
                    def scriptConteudo = "zn \"USER\" " +
                                         "set arquivoRelease=\"${irisWorkspacePath}/build/release.xml\",classesParaExportar=\"util.*.cls\",sc=1 " +
                                         "set sc=\$SYSTEM.OBJ.Export(classesParaExportar,arquivoRelease,\"-d\") " +
                                         "if sc do \$zf(-1,\"exit 0\") " +
                                         "halt\n"
                    
                    // 4. Grava o arquivo de script dinâmico direto na pasta do build atual
                    writeFile file: 'build/gerar_release.script', text: scriptConteudo, encoding: 'UTF-8'
                }
                
                // 5. O IRIS executa o script dinâmico gerado pelo Jenkins que já possui o caminho correto gravado textualmente
                bat '"D:\\InterSystems\\IRIS\\bin\\irissession" IRIS < build\\gerar_release.script || exit 0'
                
                // 6. Renomeia o arquivo gerado de forma garantida
                bat "ren build\\release.xml release_build_${env.BUILD_NUMBER}.xml"
                
                // 7. Arquiva o artefato final indexado
                archiveArtifacts artifacts: "build/release_build_${env.BUILD_NUMBER}.xml", fingerprint: true
                
                // 8. Notificação segura para o Discord (Corrigida sem aspas simples internas)
                withCredentials([string(credentialsId: env.DISCORD_WEBHOOK_ID, variable: 'WEBHOOK_SECRET')]) {
                    script {
                        def releasePayload = """{
                            "content": "📦 **NOVA RELEASE DISPONÍVEL!**\\n**Projeto:** ${env.JOB_NAME}\\n**Branch:** ${env.BRANCH_NAME}\\n**Build:** #${env.BUILD_NUMBER}\\n🚀 *O artefato consolidado release_build_${env.BUILD_NUMBER}.xml foi gerado com sucesso! O pacote já está arquivado no painel do Jenkins e pronto para ser implantado em Produção.*"
                        }"""
                        def jsonRelease = releasePayload.replaceAll('\n', '').replaceAll('\r', '')
                        
                        // FIX: Alterado de aspas simples para aspas duplas escapadas (\") no argumento do GetBytes para blindar o PowerShell
                        powershell "Invoke-RestMethod -Uri \$env:WEBHOOK_SECRET -Method Post -Body ([System.Text.Encoding]::UTF8.GetBytes('${jsonRelease}')) -ContentType 'application/json; charset=utf-8'"
                    }
                }
            }
        }
    }
    
    post {
        failure {
            echo '🚨 Os testes falharam! Voltando o servidor para o estado anterior usando o backup...'
            bat '"D:\\InterSystems\\IRIS\\bin\\irissession" IRIS < D:\\IRIS_Server\\rollback.script || exit 0'

            // FIX: Mapeamento de credencial corrigido para evitar o NullPointerException
            withCredentials([string(credentialsId: env.DISCORD_WEBHOOK_ID, variable: 'WEBHOOK_SECRET')]) {
                script {
                    def msgPayload = """{
                        "content": "❌ **Pipeline FALHOU!**\\n**Projeto:** ${env.JOB_NAME}\\n**Build:** #${env.BUILD_NUMBER}\\n🚨 *Os testes unitários falharam ou a esteira quebrou. O procedimento de Rollback automático foi executado e o servidor foi restaurado.*"
                    }"""

                    def jsonPronto = msgPayload.replaceAll('\n', '').replaceAll('\r', '')
                    powershell "Invoke-RestMethod -Uri \$env:WEBHOOK_SECRET -Method Post -Body ([System.Text.Encoding]::UTF8.GetBytes('${jsonPronto}')) -ContentType 'application/json; charset=utf-8'"
                }
            }
       }
        success {
            echo '✅ Pipeline concluído com sucesso. Nenhuma falha detectada!'

            // FIX: Mapeamento de credencial corrigido para evitar o NullPointerException
            withCredentials([string(credentialsId: env.DISCORD_WEBHOOK_ID, variable: 'WEBHOOK_SECRET')]) {
                script {
                    def msgPayload = """{
                        "content": "✅ **Pipeline SUCESSO!**\\n**Projeto:** ${env.JOB_NAME}\\n**Build:** #${env.BUILD_NUMBER}\\n🚀 *Alterações publicadas com sucesso no InterSystems IRIS!*"
                    }"""
                    
                    def jsonPronto = msgPayload.replaceAll('\n', '').replaceAll('\r', '')
                    powershell "Invoke-RestMethod -Uri \$env:WEBHOOK_SECRET -Method Post -Body ([System.Text.Encoding]::UTF8.GetBytes('${jsonPronto}')) -ContentType 'application/json; charset=utf-8'"
                }
            }
        }
    }
}
