package wgm

import grails.validation.ValidationException
import static org.springframework.http.HttpStatus.*

class FabricaController {

    FabricaService fabricaService

    static allowedMethods = [save: "POST", update: "PUT", delete: "DELETE"]

    def index(Integer max) {
        params.max = Math.min(max ?: 10, 100)
        respond fabricaService.list(params), model:[fabricaCount: fabricaService.count()]
    }

    def show(Long id) {
        respond fabricaService.get(id)
    }

    def create() {
        respond new Fabrica(params)
    }

    def save(Fabrica fabrica) {
        if (fabrica == null) {
            notFound()
            return
        }

        try {
            fabricaService.save(fabrica)
        } catch (ValidationException e) {
            respond fabrica.errors, view:'create'
            return
        }

        request.withFormat {
            form multipartForm {
                flash.message = message(code: 'default.created.message', args: [message(code: 'fabrica.label', default: 'Fabrica'), fabrica.id])
                redirect fabrica
            }
            '*' { respond fabrica, [status: CREATED] }
        }
    }

    def edit(Long id) {
        respond fabricaService.get(id)
    }

    def update(Fabrica fabrica) {
        if (fabrica == null) {
            notFound()
            return
        }

        try {
            fabricaService.save(fabrica)
        } catch (ValidationException e) {
            respond fabrica.errors, view:'edit'
            return
        }

        request.withFormat {
            form multipartForm {
                flash.message = message(code: 'default.updated.message', args: [message(code: 'fabrica.label', default: 'Fabrica'), fabrica.id])
                redirect fabrica
            }
            '*'{ respond fabrica, [status: OK] }
        }
    }

    def delete(Long id) {
        if (id == null) {
            notFound()
            return
        }

        fabricaService.delete(id)

        request.withFormat {
            form multipartForm {
                flash.message = message(code: 'default.deleted.message', args: [message(code: 'fabrica.label', default: 'Fabrica'), id])
                redirect action:"index", method:"GET"
            }
            '*'{ render status: NO_CONTENT }
        }
    }

    protected void notFound() {
        request.withFormat {
            form multipartForm {
                flash.message = message(code: 'default.not.found.message', args: [message(code: 'fabrica.label', default: 'Fabrica'), params.id])
                redirect action: "index", method: "GET"
            }
            '*'{ render status: NOT_FOUND }
        }
    }
}
