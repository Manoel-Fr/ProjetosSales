import { LightningElement } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';

export default class OpenContactCreation extends NavigationMixin(LightningElement) {
    handleCreateContact() {
        this[NavigationMixin.Navigate]({
            type: 'standard__objectPage',
            attributes: {
                objectApiName: 'Contact',
                actionName: 'new'
            }
        });
    }
}
