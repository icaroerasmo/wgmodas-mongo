<!DOCTYPE html>
<html>
    <head>
        <meta name="layout" content="main" />
        <g:set var="entityName" value="${message(code: 'distribuidora.label', default: 'Distribuidora')}" />
        <title><g:message code="default.show.label" args="[entityName]" /></title>
    </head>
    <body>
        <a href="#show-distribuidora" class="skip" tabindex="-1"><g:message code="default.link.skip.label" default="Skip to content&hellip;"/></a>
        <div class="nav" role="navigation">
            <ul>
                <li><a class="home" href="${createLink(uri: '/')}"><g:message code="default.home.label"/></a></li>
                <li><g:link class="list" action="index"><g:message code="default.list.label" args="[entityName]" /></g:link></li>
                <li><g:link class="create" action="create"><g:message code="default.new.label" args="[entityName]" /></g:link></li>
            </ul>
        </div>
        <div id="show-distribuidora" class="content scaffold-show" role="main">
            <h1><g:message code="default.show.label" args="[entityName]" /></h1>
            <g:if test="${flash.message}">
            <div class="message" role="status">${flash.message}</div>
            </g:if>
            <ol class="property-list distribuidora">
                <f:with bean="distribuidora">
                    <li class="fieldcontain">
                        <span id="cnpj-label" class="property-label">CNPJ</span>
                        <div class="property-value" aria-labelledby="cnpj-label">
                            <f:display property="cnpj"/>
                        </div>
                    </li>
                    <li class="fieldcontain">
                        <span id="razaoSocial-label" class="property-label">Razão Social</span>
                        <div class="property-value" aria-labelledby="razaoSocial-label">
                            <f:display property="razaoSocial"/>
                        </div>
                    </li>
                    <li class="fieldcontain">
                        <span id="nomeFantasia-label" class="property-label">Nome Fantasia</span>
                        <div class="property-value" aria-labelledby="nomeFantasia-label">
                            <f:display property="nomeFantasia"/>
                        </div>
                    </li>
                    <li class="fieldcontain">
                        <span id="endereco-label" class="property-label">Endereço</span>
                        <div class="property-value" aria-labelledby="endereco-label">
                            <f:display property="endereco"/>
                        </div>
                    </li>
                    <li class="fieldcontain">
                        <span id="telefone-label" class="property-label">Telefone</span>
                        <div class="property-value" aria-labelledby="telefone-label">
                            <f:display property="telefone"/>
                        </div>
                    </li>
                    <li class="fieldcontain">
                        <span id="email-label" class="property-label">E-mail</span>
                        <div class="property-value" aria-labelledby="email-label">
                            <f:display property="usuario.email"/>
                        </div>
                    </li>
                    <li class="fieldcontain">
                        <span id="senha-label" class="property-label">Senha</span>
                        <div class="property-value" aria-labelledby="senha-label">
                            <f:display property="usuario.senha"/>
                        </div>
                    </li>
                    <li class="fieldcontain">
                        <span id="pedidos-label" class="property-label">Pedidos</span>
                        <div class="property-value" aria-labelledby="pedidos-label">
                            <f:display property="pedidos"/>
                        </div>
                    </li>
                    <li class="fieldcontain">
                        <span id="pedidos-label" class="property-label">Produtos</span>
                        <div class="property-value" aria-labelledby="pedidos-label">
                            <f:display property="produtos"/>
                        </div>
                    </li>
                </f:with>
            </ol>
            <g:form resource="${this.distribuidora}" method="DELETE">
                <fieldset class="buttons">
                    <g:link class="edit" action="edit" resource="${this.distribuidora}"><g:message code="default.button.edit.label" default="Edit" /></g:link>
                    <input class="delete" type="submit" value="${message(code: 'default.button.delete.label', default: 'Delete')}" onclick="return confirm('${message(code: 'default.button.delete.confirm.message', default: 'Are you sure?')}');" />
                </fieldset>
            </g:form>
        </div>
    </body>
</html>
