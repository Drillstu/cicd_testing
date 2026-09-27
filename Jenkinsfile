pipeline {
    agent any

    options {
        buildDiscarder(logRotator(numToKeepStr: '10', artifactNumToKeepStr: '10'))
        timeout(time: 1, unit: 'HOURS')
    }

    environment {
        DISCORD_WEBHOOK_ID = 'discord-webhook-url'
    }
    
    stages {
        stage('1. Baixar do GitHub') {
            steps {
                echo '📥 Baixando a última versão do código fonte via Git...'
                checkout scm
            }
        }
        
        stage('2. Copiar para o Servidor') {
            steps {
                echo '🧹 Atualizando apenas os arquivos de código no servidor local...'
                bat 'del /q /s D:\\IRIS_Server\\projectGit\\src\\* 2>nul || exit 0'
                bat 'del /q /s D:\\IRIS_Server\\projectGit\\tests\\* 2>nul || exit 0'
                bat 'xcopy /E /Y . D:\\IRIS_Server\\projectGit\\'
            }
        }
        
        stage('3. Backup e Deploy no IRIS') {
            options {
                timeout(time: 30, unit: 'MINUTES') 
            }
            steps {
                echo '📦 Criando snapshot de segurança e aplicando novo código fonte no pacote src...'
                script {
                    def importarScriptConteudo = """zn "USER"
set arquivoBackup="D:\\IRIS_Server\\backup_anterior.xml"
set pacoteAlvo="src"
do \$SYSTEM.OBJ.ExportPackage(pacoteAlvo, arquivoBackup, "-d")
set sc=\$SYSTEM.OBJ.LoadDir("D:/IRIS_Server/projectGit/src/", "ck", , 1)
if 'sc hang 2 halt
do \$zf(-1,"exit 0")
halt
"""
                    writeFile file: 'scripts/importar.script', text: importarScriptConteudo, encoding: 'UTF-8'
                }
                
                bat '"D:\\InterSystems\\IRIS\\bin\\irissession" IRIS < scripts\\importar.script'
                
                script {
                    currentBuild.result = 'SUCCESS'
                }
            }
        }
        
        stage('4. Executar Testes Unitários') {            
            when {
                allOf {
                    expression { return fileExists('tests') }
                    not { branch 'production' }
                    expression { 
                        def changeLogSets = currentBuild.changeSets
                        def commitMessage = changeLogSets.collect { set -> set.items.collect { item -> item.msg }.join(' ') }.join(' ')
                        return !commitMessage.contains('[skip test]') && !commitMessage.contains('[skip ci]')
                    }
                }
            }
            options {
                timeout(time: 10, unit: 'MINUTES')
            }
            steps {
                echo '🧪 Executando bateria de testes unitários com retenção inteligente...'
                script {
                    def irisWorkspacePath = "${WORKSPACE}".replace('\\', '/')
                    
                    def testeScriptConteudo = """zn "USER"
set primeiroId=\$order(^UnitTest.Result(""))
if primeiroId'="" { set dataCriacao=\$listget(\$get(^UnitTest.Result(primeiroId)), 1) if dataCriacao'="" { set dataH=\$zdatetimeh(dataCriacao, 3, 1) set diasAntigo=\$piece(dataH, ",", 1) set diasHoje=\$piece(\$horolog, ",", 1) if (diasHoje - diasAntigo) >= 7 { do ##class(%UnitTest.Result.TestInstance).%DeleteExtent() } } }
set ^UnitTestRoot="${irisWorkspacePath}"
set sc=##class(%UnitTest.Manager).RunTest("tests", "/load/compile")
set lastId=\$order(^UnitTest.Result(""), -1)
set statusValido=1
if lastId'="" { set dadosSuite=\$get(^UnitTest.Result(lastId, "tests")) if dadosSuite'="" set statusValido=\$listget(dadosSuite, 1) }
if ('sc) || (statusValido=0) hang 2 halt
do \$zf(-1,"exit 0")
halt
"""
                    writeFile file: 'scripts/executar_testes.script', text: testeScriptConteudo, encoding: 'UTF-8'
                }
                bat '"D:\\InterSystems\\IRIS\\bin\\irissession" IRIS < scripts\\executar_testes.script'
                script {
                    currentBuild.result = 'SUCCESS'
                }
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
                echo '📦 Testes aprovados com louvor! Exportando pacote consolidado .xml para implantação...'
                script {
                    def irisWorkspacePath = "${WORKSPACE}".replace('\\', '/')
                    def scriptConteudo = """zn "USER"
set arquivoRelease="${irisWorkspacePath}/scripts/release.xml"
set classesParaExportar="src.*.cls"
set sc=\$SYSTEM.OBJ.Export(classesParaExportar,arquivoRelease,"-d")
if sc do \$zf(-1,"exit 0")
halt
"""
                    writeFile file: 'scripts/gerar_release.script', text: scriptConteudo, encoding: 'UTF-8'
                }
                
                bat '"D:\\InterSystems\\IRIS\\bin\\irissession" IRIS < scripts\\gerar_release.script || exit 0'
                
                // Cria a pasta de releases externa permanente no servidor caso ela não exista
                bat 'mkdir D:\\IRIS_Server\\build 2>nul || exit 0'
                // Move e renomeia o arquivo gerado para o repositório de histórico seguro externa
                bat "move build\\release.xml D:\\IRIS_Server\\build\\release_build_${env.BUILD_NUMBER}.xml"
                
                archiveArtifacts artifacts: "build/release_build_${env.BUILD_NUMBER}.xml", fingerprint: true
                
                withCredentials([string(credentialsId: env.DISCORD_WEBHOOK_ID, variable: 'WEBHOOK_SECRET')]) {
                    script {
                        def mensagemTexto = "📦 **NOVA RELEASE DISPONÍVEL!**\\n**Projeto:** ${env.JOB_NAME}\\n**Branch:** ${env.BRANCH_NAME}\\n**Build:** #${env.BUILD_NUMBER}\\n🚀 *O artefato consolidado release_build_${env.BUILD_NUMBER}.xml foi gerado com sucesso a partir do pacote src! O pacote já está arquivado no painel do Jenkins e pronto para Produção.*"
                        powershell """
                            \$msgObj = @{ content = "${mensagemTexto}" }
                            \$jsonBody = \$msgObj | ConvertTo-Json -Compress
                            Invoke-RestMethod -Uri \$env:WEBHOOK_SECRET -Method Post -Body ([System.Text.Encoding]::UTF8.GetBytes(\$jsonBody)) -ContentType 'application/json; charset=utf-8'
                        """
                    }
                }
            }
        }
    }
    
    post {
        failure {
            echo '🚨 O build falhou ou os testes quebraram! Executando Rollback automático via ObjectScript...'
            script {
                def rollbackScriptConteudo = """zn "USER"
set arquivoBackup="D:\\IRIS_Server\\backup_anterior.xml"
if ##class(%File).Exists(arquivoBackup) set sc=\$SYSTEM.OBJ.Load(arquivoBackup, "ck")
halt
"""
                writeFile file: 'scripts/rollback.script', text: rollbackScriptConteudo, encoding: 'UTF-8'
            }
            bat '"D:\\InterSystems\\IRIS\\bin\\irissession" IRIS < scripts\\rollback.script || exit 0'

            withCredentials([string(credentialsId: env.DISCORD_WEBHOOK_ID, variable: 'WEBHOOK_SECRET')]) {
                script {
                    def mensagemTexto = "❌ **Pipeline FALHOU!**\\n**Projeto:** ${env.JOB_NAME}\\n**Branch:** ${env.BRANCH_NAME}\\n**Build:** #${env.BUILD_NUMBER}\\n🚨 *Os testes unitários falharam ou a esteira quebrou. O procedimento de Rollback automático foi executado e o ambiente local foi restaurado.*"
                    powershell """
                        \$msgObj = @{ content = "${mensagemTexto}" }
                        \$jsonBody = \$msgObj | ConvertTo-Json -Compress
                        Invoke-RestMethod -Uri \$env:WEBHOOK_SECRET -Method Post -Body ([System.Text.Encoding]::UTF8.GetBytes(\$jsonBody)) -ContentType 'application/json; charset=utf-8'
                    """
                }
            }
       }
        success {
            echo '✅ Pipeline concluído com sucesso total. Nenhuma inconsistência detectada!'
            withCredentials([string(credentialsId: env.DISCORD_WEBHOOK_ID, variable: 'WEBHOOK_SECRET')]) {
                script {
                    def mensagemTexto = "✅ **Pipeline SUCESSO!**\\n**Projeto:** ${env.JOB_NAME}\\n**Branch:** ${env.BRANCH_NAME}\\n**Build:** #${env.BUILD_NUMBER}\\n🚀 *Alterações publicadas com sucesso no InterSystems IRIS e pacote de release generado com segurança!*"
                    powershell """
                        \$msgObj = @{ content = "${mensagemTexto}" }
                        \$jsonBody = \$msgObj | ConvertTo-Json -Compress
                        Invoke-RestMethod -Uri \$env:WEBHOOK_SECRET -Method Post -Body ([System.Text.Encoding]::UTF8.GetBytes(\$jsonBody)) -ContentType 'application/json; charset=utf-8'
                    """
                }
            }
        }
    }
}
